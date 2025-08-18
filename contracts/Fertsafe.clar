(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INSUFFICIENT_FUNDS (err u103))
(define-constant ERR_INVALID_AMOUNT (err u104))
(define-constant ERR_ALREADY_CLAIMED (err u105))
(define-constant ERR_EXPIRED (err u106))
(define-constant ERR_NOT_ELIGIBLE (err u107))
(define-constant ERR_INVALID_RATING (err u108))
(define-constant ERR_ALREADY_REVIEWED (err u109))
(define-constant ERR_CANNOT_REVIEW_OWN (err u110))

(define-data-var contract-admin principal CONTRACT_OWNER)
(define-data-var total-subsidies-allocated uint u0)
(define-data-var total-subsidies-claimed uint u0)
(define-data-var next-subsidy-id uint u1)
(define-data-var registration-fee uint u1000000)
(define-data-var next-feedback-id uint u1)

(define-map farmers principal {
    name: (string-ascii 50),
    farm-size: uint,
    location: (string-ascii 100),
    registered-at: uint,
    verified: bool,
    total-claimed: uint
})

(define-map subsidies uint {
    farmer: principal,
    fertilizer-type: (string-ascii 30),
    amount: uint,
    allocated-at: uint,
    expires-at: uint,
    claimed: bool,
    claimed-at: (optional uint)
})

(define-map farmer-subsidies principal (list 50 uint))

(define-map fertilizer-inventory (string-ascii 30) {
    total-stock: uint,
    allocated: uint,
    price-per-unit: uint,
    subsidy-rate: uint
})

(define-map admin-permissions principal bool)

(define-map fertilizer-feedback uint {
    farmer: principal,
    fertilizer-type: (string-ascii 30),
    rating: uint,
    effectiveness-rating: uint,
    delivery-rating: uint,
    comment: (string-ascii 200),
    submitted-at: uint,
    verified: bool
})

(define-map farmer-feedback-history principal (list 20 uint))

(define-map fertilizer-ratings (string-ascii 30) {
    total-ratings: uint,
    total-score: uint,
    total-effectiveness: uint,
    total-delivery: uint,
    average-rating: uint,
    average-effectiveness: uint,
    average-delivery: uint
})

(define-map feedback-responses uint {
    responder: principal,
    response: (string-ascii 300),
    responded-at: uint
})

(define-public (set-admin (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
        (var-set contract-admin new-admin)
        (ok true)
    )
)

(define-public (add-admin-permission (admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
        (map-set admin-permissions admin true)
        (ok true)
    )
)

(define-public (remove-admin-permission (admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
        (map-delete admin-permissions admin)
        (ok true)
    )
)

(define-private (is-admin (user principal))
    (or 
        (is-eq user (var-get contract-admin))
        (default-to false (map-get? admin-permissions user))
    )
)

(define-public (register-farmer (name (string-ascii 50)) (farm-size uint) (location (string-ascii 100)))
    (let ((farmer-data (map-get? farmers tx-sender)))
        (asserts! (is-none farmer-data) ERR_ALREADY_EXISTS)
        (asserts! (> farm-size u0) ERR_INVALID_AMOUNT)
        (try! (stx-transfer? (var-get registration-fee) tx-sender (var-get contract-admin)))
        (map-set farmers tx-sender {
            name: name,
            farm-size: farm-size,
            location: location,
            registered-at: stacks-block-height,
            verified: false,
            total-claimed: u0
        })
        (ok true)
    )
)

(define-public (verify-farmer (farmer principal))
    (let ((farmer-data (unwrap! (map-get? farmers farmer) ERR_NOT_FOUND)))
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
        (map-set farmers farmer (merge farmer-data { verified: true }))
        (ok true)
    )
)

(define-public (add-fertilizer-type (fertilizer-type (string-ascii 30)) (stock uint) (price uint) (subsidy-rate uint))
    (begin
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
        (asserts! (> stock u0) ERR_INVALID_AMOUNT)
        (asserts! (> price u0) ERR_INVALID_AMOUNT)
        (asserts! (<= subsidy-rate u100) ERR_INVALID_AMOUNT)
        (map-set fertilizer-inventory fertilizer-type {
            total-stock: stock,
            allocated: u0,
            price-per-unit: price,
            subsidy-rate: subsidy-rate
        })
        (ok true)
    )
)

(define-public (update-fertilizer-stock (fertilizer-type (string-ascii 30)) (additional-stock uint))
    (let ((current-inventory (unwrap! (map-get? fertilizer-inventory fertilizer-type) ERR_NOT_FOUND)))
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
        (map-set fertilizer-inventory fertilizer-type 
            (merge current-inventory { 
                total-stock: (+ (get total-stock current-inventory) additional-stock) 
            })
        )
        (ok true)
    )
)

(define-public (allocate-subsidy (farmer principal) (fertilizer-type (string-ascii 30)) (amount uint) (validity-blocks uint))
    (let (
        (farmer-data (unwrap! (map-get? farmers farmer) ERR_NOT_FOUND))
        (fertilizer-data (unwrap! (map-get? fertilizer-inventory fertilizer-type) ERR_NOT_FOUND))
        (subsidy-id (var-get next-subsidy-id))
        (current-subsidies (default-to (list) (map-get? farmer-subsidies farmer)))
        (expires-at (+ stacks-block-height validity-blocks))
    )
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
        (asserts! (get verified farmer-data) ERR_NOT_ELIGIBLE)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (>= (- (get total-stock fertilizer-data) (get allocated fertilizer-data)) amount) ERR_INSUFFICIENT_FUNDS)
        
        (map-set subsidies subsidy-id {
            farmer: farmer,
            fertilizer-type: fertilizer-type,
            amount: amount,
            allocated-at: stacks-block-height,
            expires-at: expires-at,
            claimed: false,
            claimed-at: none
        })
        
        (map-set farmer-subsidies farmer (unwrap! (as-max-len? (append current-subsidies subsidy-id) u50) ERR_INVALID_AMOUNT))
        
        (map-set fertilizer-inventory fertilizer-type 
            (merge fertilizer-data { 
                allocated: (+ (get allocated fertilizer-data) amount) 
            })
        )
        
        (var-set next-subsidy-id (+ subsidy-id u1))
        (var-set total-subsidies-allocated (+ (var-get total-subsidies-allocated) amount))
        
        (ok subsidy-id)
    )
)

(define-public (claim-subsidy (subsidy-id uint))
    (let (
        (subsidy-data (unwrap! (map-get? subsidies subsidy-id) ERR_NOT_FOUND))
        (farmer-data (unwrap! (map-get? farmers tx-sender) ERR_NOT_FOUND))
        (fertilizer-data (unwrap! (map-get? fertilizer-inventory (get fertilizer-type subsidy-data)) ERR_NOT_FOUND))
        (subsidy-amount (* (get amount subsidy-data) (get subsidy-rate fertilizer-data) (get price-per-unit fertilizer-data)))
        (final-amount (/ subsidy-amount u10000))
    )
        (asserts! (is-eq tx-sender (get farmer subsidy-data)) ERR_UNAUTHORIZED)
        (asserts! (not (get claimed subsidy-data)) ERR_ALREADY_CLAIMED)
        (asserts! (< stacks-block-height (get expires-at subsidy-data)) ERR_EXPIRED)
        (asserts! (get verified farmer-data) ERR_NOT_ELIGIBLE)
        
        (try! (as-contract (stx-transfer? final-amount tx-sender (get farmer subsidy-data))))
        
        (map-set subsidies subsidy-id 
            (merge subsidy-data { 
                claimed: true, 
                claimed-at: (some stacks-block-height) 
            })
        )
        
        (map-set farmers tx-sender 
            (merge farmer-data { 
                total-claimed: (+ (get total-claimed farmer-data) final-amount) 
            })
        )
        
        (var-set total-subsidies-claimed (+ (var-get total-subsidies-claimed) final-amount))
        
        (ok final-amount)
    )
)

(define-public (revoke-subsidy (subsidy-id uint))
    (let ((subsidy-data (unwrap! (map-get? subsidies subsidy-id) ERR_NOT_FOUND))
          (fertilizer-data (unwrap! (map-get? fertilizer-inventory (get fertilizer-type subsidy-data)) ERR_NOT_FOUND)))
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
        (asserts! (not (get claimed subsidy-data)) ERR_ALREADY_CLAIMED)
        
        (map-delete subsidies subsidy-id)
        
        (map-set fertilizer-inventory (get fertilizer-type subsidy-data)
            (merge fertilizer-data { 
                allocated: (- (get allocated fertilizer-data) (get amount subsidy-data)) 
            })
        )
        
        (var-set total-subsidies-allocated (- (var-get total-subsidies-allocated) (get amount subsidy-data)))
        
        (ok true)
    )
)

(define-public (set-registration-fee (new-fee uint))
    (begin
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
        (var-set registration-fee new-fee)
        (ok true)
    )
)

(define-public (submit-fertilizer-feedback (fertilizer-type (string-ascii 30)) (rating uint) (effectiveness-rating uint) (delivery-rating uint) (comment (string-ascii 200)))
    (let (
        (farmer-data (unwrap! (map-get? farmers tx-sender) ERR_NOT_FOUND))
        (feedback-id (var-get next-feedback-id))
        (current-feedback-history (default-to (list) (map-get? farmer-feedback-history tx-sender)))
        (current-ratings (default-to { total-ratings: u0, total-score: u0, total-effectiveness: u0, total-delivery: u0, average-rating: u0, average-effectiveness: u0, average-delivery: u0 } (map-get? fertilizer-ratings fertilizer-type)))
    )
        (asserts! (get verified farmer-data) ERR_NOT_ELIGIBLE)
        (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
        (asserts! (and (>= effectiveness-rating u1) (<= effectiveness-rating u5)) ERR_INVALID_RATING)
        (asserts! (and (>= delivery-rating u1) (<= delivery-rating u5)) ERR_INVALID_RATING)
        
        (map-set fertilizer-feedback feedback-id {
            farmer: tx-sender,
            fertilizer-type: fertilizer-type,
            rating: rating,
            effectiveness-rating: effectiveness-rating,
            delivery-rating: delivery-rating,
            comment: comment,
            submitted-at: stacks-block-height,
            verified: false
        })
        
        (map-set farmer-feedback-history tx-sender (unwrap! (as-max-len? (append current-feedback-history feedback-id) u20) ERR_INVALID_AMOUNT))
        
        (let (
            (new-total-ratings (+ (get total-ratings current-ratings) u1))
            (new-total-score (+ (get total-score current-ratings) rating))
            (new-total-effectiveness (+ (get total-effectiveness current-ratings) effectiveness-rating))
            (new-total-delivery (+ (get total-delivery current-ratings) delivery-rating))
            (new-average-rating (/ new-total-score new-total-ratings))
            (new-average-effectiveness (/ new-total-effectiveness new-total-ratings))
            (new-average-delivery (/ new-total-delivery new-total-ratings))
        )
            (map-set fertilizer-ratings fertilizer-type {
                total-ratings: new-total-ratings,
                total-score: new-total-score,
                total-effectiveness: new-total-effectiveness,
                total-delivery: new-total-delivery,
                average-rating: new-average-rating,
                average-effectiveness: new-average-effectiveness,
                average-delivery: new-average-delivery
            })
        )
        
        (var-set next-feedback-id (+ feedback-id u1))
        (ok feedback-id)
    )
)

(define-public (verify-feedback (feedback-id uint))
    (let ((feedback-data (unwrap! (map-get? fertilizer-feedback feedback-id) ERR_NOT_FOUND)))
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
        (map-set fertilizer-feedback feedback-id (merge feedback-data { verified: true }))
        (ok true)
    )
)

(define-public (respond-to-feedback (feedback-id uint) (response (string-ascii 300)))
    (let ((feedback-data (unwrap! (map-get? fertilizer-feedback feedback-id) ERR_NOT_FOUND)))
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
        (asserts! (get verified feedback-data) ERR_NOT_ELIGIBLE)
        (map-set feedback-responses feedback-id {
            responder: tx-sender,
            response: response,
            responded-at: stacks-block-height
        })
        (ok true)
    )
)

(define-public (moderate-feedback (feedback-id uint))
    (let ((feedback-data (unwrap! (map-get? fertilizer-feedback feedback-id) ERR_NOT_FOUND)))
        (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
        (map-delete fertilizer-feedback feedback-id)
        (ok true)
    )
)

(define-read-only (get-farmer (farmer principal))
    (map-get? farmers farmer)
)

(define-read-only (get-subsidy (subsidy-id uint))
    (map-get? subsidies subsidy-id)
)

(define-read-only (get-farmer-subsidies (farmer principal))
    (map-get? farmer-subsidies farmer)
)

(define-read-only (get-fertilizer-info (fertilizer-type (string-ascii 30)))
    (map-get? fertilizer-inventory fertilizer-type)
)

(define-read-only (get-contract-stats)
    {
        total-subsidies-allocated: (var-get total-subsidies-allocated),
        total-subsidies-claimed: (var-get total-subsidies-claimed),
        next-subsidy-id: (var-get next-subsidy-id),
        registration-fee: (var-get registration-fee),
        contract-admin: (var-get contract-admin)
    }
)

(define-read-only (is-farmer-verified (farmer principal))
    (match (map-get? farmers farmer)
        farmer-data (get verified farmer-data)
        false
    )
)

(define-read-only (get-available-fertilizer (fertilizer-type (string-ascii 30)))
    (match (map-get? fertilizer-inventory fertilizer-type)
        fertilizer-data (- (get total-stock fertilizer-data) (get allocated fertilizer-data))
        u0
    )
)

(define-read-only (calculate-subsidy-amount (fertilizer-type (string-ascii 30)) (amount uint))
    (match (map-get? fertilizer-inventory fertilizer-type)
        fertilizer-data 
            (let ((total-cost (* amount (get price-per-unit fertilizer-data)))
                  (subsidy-amount (* total-cost (get subsidy-rate fertilizer-data))))
                (/ subsidy-amount u10000))
        u0
    )
)

(define-read-only (get-feedback (feedback-id uint))
    (map-get? fertilizer-feedback feedback-id)
)

(define-read-only (get-farmer-feedback-history (farmer principal))
    (map-get? farmer-feedback-history farmer)
)

(define-read-only (get-fertilizer-ratings (fertilizer-type (string-ascii 30)))
    (map-get? fertilizer-ratings fertilizer-type)
)

(define-read-only (get-feedback-response (feedback-id uint))
    (map-get? feedback-responses feedback-id)
)

(define-read-only (get-feedback-stats)
    {
        next-feedback-id: (var-get next-feedback-id)
    }
)





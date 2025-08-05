(define-constant ERR_NOT_AUTHORIZED (err u200))
(define-constant ERR_POLICY_NOT_FOUND (err u201))
(define-constant ERR_INVALID_PREMIUM (err u202))
(define-constant ERR_CLAIM_ALREADY_FILED (err u203))
(define-constant ERR_INSUFFICIENT_COVERAGE (err u204))
(define-constant ERR_POLICY_EXPIRED (err u205))
(define-constant ERR_CLAIM_WINDOW_CLOSED (err u206))

(define-data-var policy-counter uint u0)
(define-data-var claim-counter uint u0)
(define-data-var insurance-pool uint u0)

(define-map insurance-policies
  uint
  {
    farm-id: uint,
    investor: principal,
    coverage-amount: uint,
    premium-paid: uint,
    policy-start-block: uint,
    policy-duration-blocks: uint,
    active: bool
  }
)

(define-map insurance-claims
  uint
  {
    policy-id: uint,
    claim-amount: uint,
    reason: (string-ascii 100),
    claim-block: uint,
    approved: bool,
    processed: bool
  }
)

(define-map investor-policies
  { farm-id: uint, investor: principal }
  uint
)

(define-read-only (get-policy (policy-id uint))
  (map-get? insurance-policies policy-id)
)

(define-read-only (get-claim (claim-id uint))
  (map-get? insurance-claims claim-id)
)

(define-read-only (get-investor-policy (farm-id uint) (investor principal))
  (map-get? investor-policies { farm-id: farm-id, investor: investor })
)

(define-read-only (get-insurance-pool)
  (var-get insurance-pool)
)

(define-read-only (calculate-premium (coverage-amount uint) (duration-blocks uint))
  (/ (* coverage-amount duration-blocks) u100000)
)

(define-public (purchase-policy (farm-id uint) (coverage-amount uint) (duration-blocks uint))
  (let
    (
      (new-policy-id (+ (var-get policy-counter) u1))
      (premium (calculate-premium coverage-amount duration-blocks))
    )
    (asserts! (> coverage-amount u0) ERR_INVALID_PREMIUM)
    (asserts! (> duration-blocks u0) ERR_INVALID_PREMIUM)
    (asserts! (> premium u0) ERR_INVALID_PREMIUM)
    
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    
    (map-set insurance-policies new-policy-id
      {
        farm-id: farm-id,
        investor: tx-sender,
        coverage-amount: coverage-amount,
        premium-paid: premium,
        policy-start-block: stacks-block-height,
        policy-duration-blocks: duration-blocks,
        active: true
      }
    )
    
    (map-set investor-policies
      { farm-id: farm-id, investor: tx-sender }
      new-policy-id
    )
    
    (var-set policy-counter new-policy-id)
    (var-set insurance-pool (+ (var-get insurance-pool) premium))
    (ok new-policy-id)
  )
)

(define-public (file-claim (policy-id uint) (claim-amount uint) (reason (string-ascii 100)))
  (let
    (
      (policy (unwrap! (get-policy policy-id) ERR_POLICY_NOT_FOUND))
      (new-claim-id (+ (var-get claim-counter) u1))
      (policy-end-block (+ (get policy-start-block policy) (get policy-duration-blocks policy)))
    )
    (asserts! (is-eq tx-sender (get investor policy)) ERR_NOT_AUTHORIZED)
    (asserts! (get active policy) ERR_POLICY_EXPIRED)
    (asserts! (<= stacks-block-height policy-end-block) ERR_POLICY_EXPIRED)
    (asserts! (<= claim-amount (get coverage-amount policy)) ERR_INSUFFICIENT_COVERAGE)
    
    (map-set insurance-claims new-claim-id
      {
        policy-id: policy-id,
        claim-amount: claim-amount,
        reason: reason,
        claim-block: stacks-block-height,
        approved: false,
        processed: false
      }
    )
    
    (var-set claim-counter new-claim-id)
    (ok new-claim-id)
  )
)

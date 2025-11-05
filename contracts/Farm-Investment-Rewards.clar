(define-constant ERR_NOT_AUTHORIZED (err u500))
(define-constant ERR_INVALID_POINTS (err u501))
(define-constant ERR_TIER_NOT_UNLOCKED (err u502))
(define-constant ERR_REWARD_ALREADY_CLAIMED (err u503))
(define-constant ERR_INSUFFICIENT_POINTS (err u504))

(define-data-var total-points-distributed uint u0)

(define-map investor-loyalty
  principal
  {
    total-points: uint,
    current-tier: (string-ascii 20),
    points-claimed: uint,
    last-boost-block: uint,
    consecutive-investments: uint,
    lifetime-investment: uint
  }
)

(define-map tier-benefits
  (string-ascii 20)
  {
    min-points: uint,
    yield-boost-percent: uint,
    early-access: bool,
    bonus-multiplier: uint
  }
)

(define-map investment-points-tracker
  { investor: principal, farm-id: uint }
  {
    base-points: uint,
    bonus-points: uint,
    last-claim-block: uint
  }
)

(define-private (initialize-tiers)
  (begin
    (map-set tier-benefits "Bronze" { min-points: u0, yield-boost-percent: u0, early-access: false, bonus-multiplier: u100 })
    (map-set tier-benefits "Silver" { min-points: u1000, yield-boost-percent: u5, early-access: false, bonus-multiplier: u110 })
    (map-set tier-benefits "Gold" { min-points: u5000, yield-boost-percent: u10, early-access: true, bonus-multiplier: u125 })
    (map-set tier-benefits "Platinum" { min-points: u15000, yield-boost-percent: u20, early-access: true, bonus-multiplier: u150 })
    true
  )
)

(define-read-only (get-investor-loyalty (investor principal))
  (map-get? investor-loyalty investor)
)

(define-read-only (get-tier-benefits (tier (string-ascii 20)))
  (map-get? tier-benefits tier)
)

(define-read-only (get-investment-points (investor principal) (farm-id uint))
  (map-get? investment-points-tracker { investor: investor, farm-id: farm-id })
)

(define-read-only (calculate-tier (total-points uint))
  (if (>= total-points u15000)
    (ok "Platinum")
    (if (>= total-points u5000)
      (ok "Gold")
      (if (>= total-points u1000)
        (ok "Silver")
        (ok "Bronze")
      )
    )
  )
)

(define-public (award-investment-points (investor principal) (farm-id uint) (investment-amount uint) (farm-reputation uint))
  (let
    (
      (base-points (/ investment-amount u1000))
      (reputation-bonus (/ (* base-points farm-reputation) u100))
      (total-new-points (+ base-points reputation-bonus))
      (current-loyalty (default-to 
        { total-points: u0, current-tier: "Bronze", points-claimed: u0, last-boost-block: u0, consecutive-investments: u0, lifetime-investment: u0 }
        (get-investor-loyalty investor)))
      (new-total-points (+ (get total-points current-loyalty) total-new-points))
      (new-tier (unwrap! (calculate-tier new-total-points) ERR_INVALID_POINTS))
      (new-consecutive (+ (get consecutive-investments current-loyalty) u1))
    )
    (map-set investment-points-tracker
      { investor: investor, farm-id: farm-id }
      {
        base-points: base-points,
        bonus-points: reputation-bonus,
        last-claim-block: stacks-block-height
      }
    )
    (map-set investor-loyalty investor
      (merge current-loyalty {
        total-points: new-total-points,
        current-tier: new-tier,
        consecutive-investments: new-consecutive,
        lifetime-investment: (+ (get lifetime-investment current-loyalty) investment-amount)
      })
    )
    (var-set total-points-distributed (+ (var-get total-points-distributed) total-new-points))
    (ok total-new-points)
  )
)

(define-public (apply-loyalty-boost (investor principal) (base-yield uint))
  (let
    (
      (loyalty (unwrap! (get-investor-loyalty investor) ERR_NOT_AUTHORIZED))
      (current-tier (get current-tier loyalty))
      (tier-info (unwrap! (get-tier-benefits current-tier) ERR_TIER_NOT_UNLOCKED))
      (boost-percent (get yield-boost-percent tier-info))
      (boosted-yield (+ base-yield (/ (* base-yield boost-percent) u100)))
    )
    (map-set investor-loyalty investor
      (merge loyalty { last-boost-block: stacks-block-height })
    )
    (ok boosted-yield)
  )
)

(define-public (claim-streak-bonus (investor principal))
  (let
    (
      (loyalty (unwrap! (get-investor-loyalty investor) ERR_NOT_AUTHORIZED))
      (streak (get consecutive-investments loyalty))
      (bonus-points (if (>= streak u10) u500 (if (>= streak u5) u200 (if (>= streak u3) u50 u0))))
    )
    (asserts! (> bonus-points u0) ERR_INSUFFICIENT_POINTS)
    (map-set investor-loyalty investor
      (merge loyalty {
        total-points: (+ (get total-points loyalty) bonus-points),
        consecutive-investments: u0
      })
    )
    (ok bonus-points)
  )
)

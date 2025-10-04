(define-constant ERR_NOT_AUTHORIZED (err u400))
(define-constant ERR_FARM_NOT_FOUND (err u401))
(define-constant ERR_INVALID_RATING (err u402))
(define-constant ERR_ALREADY_RATED (err u403))
(define-constant ERR_NO_INVESTMENT (err u404))

(define-map farm-analytics
  uint
  {
    total-revenue-recorded: uint,
    harvest-count: uint,
    on-time-harvests: uint,
    late-harvests: uint,
    total-investors: uint,
    average-rating: uint,
    total-ratings: uint,
    reputation-score: uint,
    last-updated-block: uint
  }
)

(define-map investor-ratings
  { farm-id: uint, investor: principal }
  {
    rating: uint,
    comment: (string-ascii 150),
    rated-block: uint
  }
)

(define-map farm-revenue-history
  { farm-id: uint, harvest-index: uint }
  {
    revenue: uint,
    block-height: uint,
    expected-block: uint,
    on-time: bool
  }
)

(define-read-only (get-farm-analytics (farm-id uint))
  (map-get? farm-analytics farm-id)
)

(define-read-only (get-investor-rating (farm-id uint) (investor principal))
  (map-get? investor-ratings { farm-id: farm-id, investor: investor })
)

(define-read-only (get-harvest-record (farm-id uint) (harvest-index uint))
  (map-get? farm-revenue-history { farm-id: farm-id, harvest-index: harvest-index })
)

(define-read-only (calculate-reputation-score (farm-id uint))
  (match (get-farm-analytics farm-id)
    analytics
    (let
      (
        (harvest-total (get harvest-count analytics))
        (on-time-rate (if (> harvest-total u0)
          (/ (* (get on-time-harvests analytics) u100) harvest-total)
          u100))
        (rating-score (get average-rating analytics))
        (investor-trust (if (< (get total-investors analytics) u20)
                           (get total-investors analytics)
                           u20))
        (weighted-score (+ 
          (/ (* on-time-rate u40) u100)
          (/ (* rating-score u40) u100)
          (/ (* investor-trust u20) u20)
        ))
      )
      (ok weighted-score)
    )
    (ok u0)
  )
)

(define-public (initialize-farm-analytics (farm-id uint))
  (begin
    (asserts! (is-none (get-farm-analytics farm-id)) ERR_FARM_NOT_FOUND)
    (map-set farm-analytics farm-id
      {
        total-revenue-recorded: u0,
        harvest-count: u0,
        on-time-harvests: u0,
        late-harvests: u0,
        total-investors: u0,
        average-rating: u100,
        total-ratings: u0,
        reputation-score: u100,
        last-updated-block: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (record-harvest-performance (farm-id uint) (revenue uint) (expected-block uint))
  (let
    (
      (analytics (default-to 
        { total-revenue-recorded: u0, harvest-count: u0, on-time-harvests: u0, 
          late-harvests: u0, total-investors: u0, average-rating: u100, 
          total-ratings: u0, reputation-score: u100, last-updated-block: u0 }
        (get-farm-analytics farm-id)))
      (current-harvest (+ (get harvest-count analytics) u1))
      (is-on-time (<= stacks-block-height expected-block))
      (new-on-time (if is-on-time (+ (get on-time-harvests analytics) u1) (get on-time-harvests analytics)))
      (new-late (if is-on-time (get late-harvests analytics) (+ (get late-harvests analytics) u1)))
    )
    (map-set farm-revenue-history
      { farm-id: farm-id, harvest-index: current-harvest }
      {
        revenue: revenue,
        block-height: stacks-block-height,
        expected-block: expected-block,
        on-time: is-on-time
      }
    )
    (map-set farm-analytics farm-id
      (merge analytics {
        total-revenue-recorded: (+ (get total-revenue-recorded analytics) revenue),
        harvest-count: current-harvest,
        on-time-harvests: new-on-time,
        late-harvests: new-late,
        last-updated-block: stacks-block-height
      })
    )
    (ok true)
  )
)

(define-public (submit-investor-rating (farm-id uint) (rating uint) (comment (string-ascii 150)))
  (let
    (
      (analytics (unwrap! (get-farm-analytics farm-id) ERR_FARM_NOT_FOUND))
      (existing-rating (get-investor-rating farm-id tx-sender))
      (total-ratings (get total-ratings analytics))
      (current-avg (get average-rating analytics))
      (new-total-ratings (+ total-ratings u1))
      (new-average (/ (+ (* current-avg total-ratings) rating) new-total-ratings))
    )
    (asserts! (is-none existing-rating) ERR_ALREADY_RATED)
    (asserts! (and (>= rating u1) (<= rating u100)) ERR_INVALID_RATING)
    
    (map-set investor-ratings
      { farm-id: farm-id, investor: tx-sender }
      {
        rating: rating,
        comment: comment,
        rated-block: stacks-block-height
      }
    )
    (map-set farm-analytics farm-id
      (merge analytics {
        average-rating: new-average,
        total-ratings: new-total-ratings
      })
    )
    (ok new-average)
  )
)

(define-public (increment-investor-count (farm-id uint))
  (let
    (
      (analytics (unwrap! (get-farm-analytics farm-id) ERR_FARM_NOT_FOUND))
    )
    (map-set farm-analytics farm-id
      (merge analytics {
        total-investors: (+ (get total-investors analytics) u1)
      })
    )
    (ok true)
  )
)

(define-public (update-reputation (farm-id uint))
  (let
    (
      (new-score (unwrap! (calculate-reputation-score farm-id) ERR_FARM_NOT_FOUND))
      (analytics (unwrap! (get-farm-analytics farm-id) ERR_FARM_NOT_FOUND))
    )
    (map-set farm-analytics farm-id
      (merge analytics { reputation-score: new-score })
    )
    (ok new-score)
  )
)

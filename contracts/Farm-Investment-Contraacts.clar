(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_FARM_NOT_FOUND (err u101))
(define-constant ERR_INSUFFICIENT_FUNDS (err u102))
(define-constant ERR_INVESTMENT_NOT_FOUND (err u103))
(define-constant ERR_FARM_INACTIVE (err u104))
(define-constant ERR_INVALID_AMOUNT (err u105))
(define-constant ERR_HARVEST_NOT_READY (err u106))
(define-constant ERR_NFT_NOT_FOUND (err u107))
(define-constant ERR_NOT_NFT_OWNER (err u108))

(define-non-fungible-token yield-rights uint)

(define-data-var farm-counter uint u0)
(define-data-var investment-counter uint u0)
(define-data-var nft-counter uint u0)

(define-map farms
  uint
  {
    owner: principal,
    name: (string-ascii 50),
    funding-goal: uint,
    current-funding: uint,
    revenue-share-percent: uint,
    active: bool,
    harvest-cycle-blocks: uint,
    last-harvest-block: uint
  }
)

(define-map investments
  uint
  {
    investor: principal,
    farm-id: uint,
    amount: uint,
    investment-block: uint,
    nft-id: uint
  }
)

(define-map farm-investors
  { farm-id: uint, investor: principal }
  { investment-id: uint, share-percentage: uint }
)

(define-map nft-metadata
  uint
  {
    farm-id: uint,
    investment-amount: uint,
    yield-percentage: uint,
    created-block: uint
  }
)

(define-map farm-revenues
  uint
  uint
)

(define-map pending-yields
  { farm-id: uint, investor: principal }
  uint
)

(define-read-only (get-farm (farm-id uint))
  (map-get? farms farm-id)
)

(define-read-only (get-investment (investment-id uint))
  (map-get? investments investment-id)
)

(define-read-only (get-farm-investor-info (farm-id uint) (investor principal))
  (map-get? farm-investors { farm-id: farm-id, investor: investor })
)

(define-read-only (get-nft-metadata (nft-id uint))
  (map-get? nft-metadata nft-id)
)

(define-read-only (get-farm-revenue (farm-id uint))
  (default-to u0 (map-get? farm-revenues farm-id))
)

(define-read-only (get-pending-yield (farm-id uint) (investor principal))
  (default-to u0 (map-get? pending-yields { farm-id: farm-id, investor: investor }))
)

(define-read-only (get-farm-counter)
  (var-get farm-counter)
)

(define-read-only (get-investment-counter)
  (var-get investment-counter)
)

(define-read-only (get-nft-counter)
  (var-get nft-counter)
)

(define-public (create-farm (name (string-ascii 50)) (funding-goal uint) (revenue-share-percent uint) (harvest-cycle-blocks uint))
  (let
    (
      (new-farm-id (+ (var-get farm-counter) u1))
    )
    (asserts! (> funding-goal u0) ERR_INVALID_AMOUNT)
    (asserts! (<= revenue-share-percent u100) ERR_INVALID_AMOUNT)
    (asserts! (> harvest-cycle-blocks u0) ERR_INVALID_AMOUNT)
    
    (map-set farms new-farm-id
      {
        owner: tx-sender,
        name: name,
        funding-goal: funding-goal,
        current-funding: u0,
        revenue-share-percent: revenue-share-percent,
        active: true,
        harvest-cycle-blocks: harvest-cycle-blocks,
        last-harvest-block: stacks-block-height
      }
    )
    (var-set farm-counter new-farm-id)
    (ok new-farm-id)
  )
)

(define-public (invest-in-farm (farm-id uint) (amount uint))
  (let
    (
      (farm (unwrap! (get-farm farm-id) ERR_FARM_NOT_FOUND))
      (new-investment-id (+ (var-get investment-counter) u1))
      (new-nft-id (+ (var-get nft-counter) u1))
      (new-funding (+ (get current-funding farm) amount))
      (share-percentage (/ (* amount u100) (get funding-goal farm)))
    )
    (asserts! (get active farm) ERR_FARM_INACTIVE)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= new-funding (get funding-goal farm)) ERR_INVALID_AMOUNT)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set investments new-investment-id
      {
        investor: tx-sender,
        farm-id: farm-id,
        amount: amount,
        investment-block: stacks-block-height,
        nft-id: new-nft-id
      }
    )
    
    (map-set farm-investors
      { farm-id: farm-id, investor: tx-sender }
      { investment-id: new-investment-id, share-percentage: share-percentage }
    )
    
    (map-set farms farm-id
      (merge farm { current-funding: new-funding })
    )
    
    (try! (nft-mint? yield-rights new-nft-id tx-sender))
    
    (map-set nft-metadata new-nft-id
      {
        farm-id: farm-id,
        investment-amount: amount,
        yield-percentage: share-percentage,
        created-block: stacks-block-height
      }
    )
    
    (var-set investment-counter new-investment-id)
    (var-set nft-counter new-nft-id)
    (ok new-investment-id)
  )
)

(define-public (add-farm-revenue (farm-id uint) (revenue uint))
  (let
    (
      (farm (unwrap! (get-farm farm-id) ERR_FARM_NOT_FOUND))
      (current-revenue (get-farm-revenue farm-id))
    )
    (asserts! (is-eq tx-sender (get owner farm)) ERR_NOT_AUTHORIZED)
    (asserts! (> revenue u0) ERR_INVALID_AMOUNT)
    
    (map-set farm-revenues farm-id (+ current-revenue revenue))
    (ok true)
  )
)

(define-public (distribute-yields (farm-id uint))
  (let
    (
      (farm (unwrap! (get-farm farm-id) ERR_FARM_NOT_FOUND))
      (total-revenue (get-farm-revenue farm-id))
      (blocks-since-harvest (- stacks-block-height (get last-harvest-block farm)))
    )
    (asserts! (is-eq tx-sender (get owner farm)) ERR_NOT_AUTHORIZED)
    (asserts! (>= blocks-since-harvest (get harvest-cycle-blocks farm)) ERR_HARVEST_NOT_READY)
    (asserts! (> total-revenue u0) ERR_INVALID_AMOUNT)
    
    (map-set farms farm-id
      (merge farm { last-harvest-block: stacks-block-height })
    )
    
    (map-set farm-revenues farm-id u0)
    (ok total-revenue)
  )
)

(define-public (claim-yield (farm-id uint))
  (let
    (
      (farm (unwrap! (get-farm farm-id) ERR_FARM_NOT_FOUND))
      (investor-info (unwrap! (get-farm-investor-info farm-id tx-sender) ERR_INVESTMENT_NOT_FOUND))
      (pending-yield (get-pending-yield farm-id tx-sender))
    )
    (asserts! (> pending-yield u0) ERR_INVALID_AMOUNT)
    
    (try! (as-contract (stx-transfer? pending-yield tx-sender tx-sender)))
    
    (map-delete pending-yields { farm-id: farm-id, investor: tx-sender })
    (ok pending-yield)
  )
)

(define-public (calculate-investor-yield (farm-id uint) (investor principal) (total-revenue uint))
  (let
    (
      (investor-info (unwrap! (get-farm-investor-info farm-id investor) ERR_INVESTMENT_NOT_FOUND))
      (farm (unwrap! (get-farm farm-id) ERR_FARM_NOT_FOUND))
      (investor-share (get share-percentage investor-info))
      (revenue-share-percent (get revenue-share-percent farm))
      (distributable-revenue (/ (* total-revenue revenue-share-percent) u100))
      (investor-yield (/ (* distributable-revenue investor-share) u100))
      (current-pending (get-pending-yield farm-id investor))
    )
    (map-set pending-yields
      { farm-id: farm-id, investor: investor }
      (+ current-pending investor-yield)
    )
    (ok investor-yield)
  )
)

(define-public (transfer-yield-nft (nft-id uint) (recipient principal))
  (let
    (
      (current-owner (unwrap! (nft-get-owner? yield-rights nft-id) ERR_NFT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender current-owner) ERR_NOT_NFT_OWNER)
    (try! (nft-transfer? yield-rights nft-id tx-sender recipient))
    (ok true)
  )
)

(define-public (deactivate-farm (farm-id uint))
  (let
    (
      (farm (unwrap! (get-farm farm-id) ERR_FARM_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner farm)) ERR_NOT_AUTHORIZED)
    
    (map-set farms farm-id
      (merge farm { active: false })
    )
    (ok true)
  )
)

(define-public (withdraw-farm-funds (farm-id uint) (amount uint))
  (let
    (
      (farm (unwrap! (get-farm farm-id) ERR_FARM_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner farm)) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (try! (as-contract (stx-transfer? amount tx-sender (get owner farm))))
    (ok true)
  )
)

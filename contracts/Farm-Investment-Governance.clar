(define-constant ERR_NOT_AUTHORIZED (err u300))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u301))
(define-constant ERR_ALREADY_VOTED (err u302))
(define-constant ERR_VOTING_ENDED (err u303))
(define-constant ERR_VOTING_ACTIVE (err u304))
(define-constant ERR_INSUFFICIENT_VOTING_POWER (err u305))

(define-data-var proposal-counter uint u0)

(define-map governance-proposals
  uint
  {
    farm-id: uint,
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 300),
    proposal-type: (string-ascii 50),
    voting-end-block: uint,
    total-votes-for: uint,
    total-votes-against: uint,
    executed: bool,
    created-block: uint
  }
)

(define-map proposal-votes
  { proposal-id: uint, voter: principal }
  {
    vote-for: bool,
    voting-power: uint,
    vote-block: uint
  }
)

(define-map voter-eligibility
  { farm-id: uint, voter: principal }
  uint
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? governance-proposals proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? proposal-votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-voting-power (farm-id uint) (voter principal))
  (default-to u0 (map-get? voter-eligibility { farm-id: farm-id, voter: voter }))
)

(define-public (create-proposal (farm-id uint) (title (string-ascii 100)) (description (string-ascii 300)) (proposal-type (string-ascii 50)) (voting-duration-blocks uint))
  (let
    (
      (new-proposal-id (+ (var-get proposal-counter) u1))
      (voting-power (get-voting-power farm-id tx-sender))
    )
    (asserts! (> voting-power u10) ERR_INSUFFICIENT_VOTING_POWER)
    (asserts! (> voting-duration-blocks u0) ERR_NOT_AUTHORIZED)
    
    (map-set governance-proposals new-proposal-id
      {
        farm-id: farm-id,
        proposer: tx-sender,
        title: title,
        description: description,
        proposal-type: proposal-type,
        voting-end-block: (+ stacks-block-height voting-duration-blocks),
        total-votes-for: u0,
        total-votes-against: u0,
        executed: false,
        created-block: stacks-block-height
      }
    )
    
    (var-set proposal-counter new-proposal-id)
    (ok new-proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let
    (
      (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (voting-power (get-voting-power (get farm-id proposal) tx-sender))
      (existing-vote (get-vote proposal-id tx-sender))
    )
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    (asserts! (<= stacks-block-height (get voting-end-block proposal)) ERR_VOTING_ENDED)
    (asserts! (> voting-power u0) ERR_INSUFFICIENT_VOTING_POWER)
    
    (map-set proposal-votes
      { proposal-id: proposal-id, voter: tx-sender }
      {
        vote-for: vote-for,
        voting-power: voting-power,
        vote-block: stacks-block-height
      }
    )
    
    (if vote-for
      (map-set governance-proposals proposal-id
        (merge proposal { total-votes-for: (+ (get total-votes-for proposal) voting-power) })
      )
      (map-set governance-proposals proposal-id
        (merge proposal { total-votes-against: (+ (get total-votes-against proposal) voting-power) })
      )
    )
    
    (ok true)
  )
)

(define-public (set-voting-power (farm-id uint) (voter principal) (power uint))
  (begin
    (map-set voter-eligibility { farm-id: farm-id, voter: voter } power)
    (ok true)
  )
)

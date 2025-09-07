(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_FARM_NOT_FOUND (err u101))
(define-constant ERR_MILESTONE_NOT_FOUND (err u102))
(define-constant ERR_INVALID_MILESTONE_ID (err u103))
(define-constant ERR_MILESTONE_ALREADY_COMPLETED (err u104))

(define-data-var milestone-counter uint u0)

(define-map farm-milestones
  { farm-id: uint, milestone-id: uint }
  {
    title: (string-ascii 50),
    description: (string-ascii 200),
    target-completion-block: uint,
    completed: bool,
    completion-block: (optional uint),
    evidence-link: (optional (string-ascii 100))
  }
)

(define-map farm-milestone-count
  uint
  uint
)

(define-read-only (get-milestone (farm-id uint) (milestone-id uint))
  (map-get? farm-milestones { farm-id: farm-id, milestone-id: milestone-id })
)

(define-read-only (get-farm-milestone-count (farm-id uint))
  (default-to u0 (map-get? farm-milestone-count farm-id))
)

(define-read-only (get-milestone-counter)
  (var-get milestone-counter)
)

(define-public (create-milestone (farm-id uint) (title (string-ascii 50)) (description (string-ascii 200)) (target-completion-block uint))
  (let
    (
      (new-milestone-id (+ (get-farm-milestone-count farm-id) u1))
    )
    (asserts! (> target-completion-block stacks-block-height) ERR_INVALID_MILESTONE_ID)
    
    (map-set farm-milestones
      { farm-id: farm-id, milestone-id: new-milestone-id }
      {
        title: title,
        description: description,
        target-completion-block: target-completion-block,
        completed: false,
        completion-block: none,
        evidence-link: none
      }
    )
    
    (map-set farm-milestone-count farm-id new-milestone-id)
    (var-set milestone-counter (+ (var-get milestone-counter) u1))
    (ok new-milestone-id)
  )
)

(define-public (complete-milestone (farm-id uint) (milestone-id uint) (evidence-link (optional (string-ascii 100))))
  (let
    (
      (milestone (unwrap! (get-milestone farm-id milestone-id) ERR_MILESTONE_NOT_FOUND))
    )
    (asserts! (not (get completed milestone)) ERR_MILESTONE_ALREADY_COMPLETED)
    
    (map-set farm-milestones
      { farm-id: farm-id, milestone-id: milestone-id }
      (merge milestone {
        completed: true,
        completion-block: (some stacks-block-height),
        evidence-link: evidence-link
      })
    )
    (ok true)
  )
)

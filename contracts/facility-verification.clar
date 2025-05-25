;; Facility Verification Contract
;; Validates and manages production site certifications

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-facility-exists (err u101))
(define-constant err-facility-not-found (err u102))
(define-constant err-invalid-status (err u103))

;; Facility status types
(define-constant status-pending u0)
(define-constant status-verified u1)
(define-constant status-suspended u2)
(define-constant status-revoked u3)

;; Data structures
(define-map facilities
  { facility-id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    location: (string-ascii 200),
    certification-date: uint,
    status: uint,
    verifier: principal
  }
)

(define-map facility-capabilities
  { facility-id: uint, capability: (string-ascii 50) }
  { certified: bool, certification-date: uint }
)

(define-data-var next-facility-id uint u1)

;; Register a new facility
(define-public (register-facility (name (string-ascii 100)) (location (string-ascii 200)))
  (let ((facility-id (var-get next-facility-id)))
    (asserts! (is-none (map-get? facilities { facility-id: facility-id })) err-facility-exists)
    (map-set facilities
      { facility-id: facility-id }
      {
        owner: tx-sender,
        name: name,
        location: location,
        certification-date: block-height,
        status: status-pending,
        verifier: contract-owner
      }
    )
    (var-set next-facility-id (+ facility-id u1))
    (ok facility-id)
  )
)

;; Verify facility (admin only)
(define-public (verify-facility (facility-id uint))
  (let ((facility (unwrap! (map-get? facilities { facility-id: facility-id }) err-facility-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set facilities
      { facility-id: facility-id }
      (merge facility { status: status-verified, verifier: tx-sender })
    )
    (ok true)
  )
)

;; Add capability certification
(define-public (certify-capability (facility-id uint) (capability (string-ascii 50)))
  (let ((facility (unwrap! (map-get? facilities { facility-id: facility-id }) err-facility-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-eq (get status facility) status-verified) err-invalid-status)
    (map-set facility-capabilities
      { facility-id: facility-id, capability: capability }
      { certified: true, certification-date: block-height }
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-facility (facility-id uint))
  (map-get? facilities { facility-id: facility-id })
)

(define-read-only (get-facility-capability (facility-id uint) (capability (string-ascii 50)))
  (map-get? facility-capabilities { facility-id: facility-id, capability: capability })
)

(define-read-only (is-facility-verified (facility-id uint))
  (match (map-get? facilities { facility-id: facility-id })
    facility (is-eq (get status facility) status-verified)
    false
  )
)

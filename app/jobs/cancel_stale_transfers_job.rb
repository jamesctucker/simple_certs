class CancelStaleTransfersJob < ApplicationJob
  queue_as :default

  def perform
    stale_transfers = CertificateQuantity.where(status: "intransit").where("intransit_at < ?", stale_threshold)
    ids = stale_transfers.pluck(:id)
    stale_transfers.find_each(&:cancel_transfer!)
    Rails.logger.info "CancelStaleTransfersJob: Cancelled #{ids.size} stale transfers (ids: #{ids.join(',')})"
  end
  # If cancel_transfer! raises an exception, ActiveJob will log it automatically

  private

  def stale_threshold
    threshold_hours = ENV.fetch("STALE_TRANSFER_HOURS_THRESHOLD", 24).to_i
    threshold_hours.hours.ago
  end
end

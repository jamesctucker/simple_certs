class CancelStaleTransfersJob < ApplicationJob
  queue_as :default

  def perform
    stale_records = CertificateQuantity.where(status: "intransit").where("intransit_at < ?", stale_threshold)

    count = stale_records.count
    stale_records.find_each(&:cancel_transfer!)
    Rails.logger.info "CancelStaleTransfersJob: Cancelled #{count} stale transfers"
  end
  # If cancel_transfer! raises an exception, ActiveJob will log it automatically

  private

  def stale_threshold
    threshold_hours = ENV.fetch("STALE_TRANSFER_HOURS_THRESHOLD", 24).to_i
    threshold_hours.hours.ago
  end
end

namespace :transfers do
  desc "Cancel stale transfers that have been in transit too long"
  task cancel_stale: :environment do
    threshold_hours = ENV.fetch("STALE_TRANSFER_THRESHOLD_HOURS", "24").to_i
    cutoff_time = threshold_hours.hours.ago

    stale_count = CertificateQuantity.where(status: "intransit")
                                     .where("intransit_at < ?", cutoff_time)
                                     .count
    puts "Found #{stale_count} stale transfers to cancel (threshold: #{threshold_hours} hours)"
    CancelStaleTransfersJob.perform_now
    puts "Job completed."
  end

  desc "Create demo stale transfer (intransit older than threshold)"
  task create_stale_test_data: :environment do
    threshold_hours = ENV.fetch("STALE_TRANSFER_THRESHOLD_HOURS", "24").to_i
    backdate = (threshold_hours + 1).hours.ago

    cq = CertificateQuantity.where(status: "active").first

    unless cq
      org_a = Organization.first || Organization.create!(name: "Demo Org A")
      gen = org_a.generators.first || Generator.create!(name: "Demo Gen", ext_id: SecureRandom.hex(4), organization: org_a)
      gen_rec = gen.generations.first || Generation.create!(
        start_date: Date.today.beginning_of_month,
        end_date: Date.today.beginning_of_month.end_of_month,
        quantity: 100,
        generator: gen
      )
      cert = gen_rec.certificate || Certificate.create!(generator: gen, generation: gen_rec, quantity: gen_rec.quantity)
      cq = cert.certificate_quantities.first
    end

    recipient_org = Organization.where.not(id: cq.account.organization_id).first || Organization.create!(name: "Demo Org B")
    cq.update!(status: "intransit", to_organization: recipient_org, intransit_at: backdate)

    puts "Created stale transfer: CertificateQuantity ##{cq.id}"
    puts "  to_organization_id: #{recipient_org.id}"
    puts "  intransit_at: #{cq.intransit_at.iso8601} (threshold: #{threshold_hours}h)"
    puts "Run: rails transfers:cancel_stale"
  end
end
require 'rails_helper'

RSpec.describe CancelStaleTransfersJob, type: :job do
  let(:organization1) { create(:organization) }
  let(:organization2) { create(:organization) }
  let(:generator) { create(:generator, organization: organization1) }
  let(:generation) { create(:generation, generator: generator) }
  let(:certificate) { create(:certificate, generator: generator, generation: generation) }
  
  describe '#perform' do
    it 'cancels stale transfers older than threshold' do
      # Test with default 24 hour threshold
      stale_transfer = create(:certificate_quantity, 
        certificate: certificate,
        account: organization1.default_account,
        status: 'intransit',
        to_organization: organization2,
        intransit_at: 25.hours.ago
      )
      
      expect { described_class.perform_now }
        .to change { stale_transfer.reload.status }.from('intransit').to('active')
    end

    it 'respects custom ENV threshold' do
      # Test with custom 1 hour threshold
      allow(ENV).to receive(:fetch).with("STALE_TRANSFER_HOURS_THRESHOLD", 24).and_return("1")
      
      stale_transfer = create(:certificate_quantity, 
        certificate: certificate,
        account: organization1.default_account,
        status: 'intransit',
        to_organization: organization2,
        intransit_at: 2.hours.ago
      )
      
      expect { described_class.perform_now }
        .to change { stale_transfer.reload.status }.from('intransit').to('active')
    end

    it 'does not cancel fresh transfers within custom threshold' do
      allow(ENV).to receive(:fetch).with("STALE_TRANSFER_HOURS_THRESHOLD", 24).and_return("2")
      
      fresh_transfer = create(:certificate_quantity,
        certificate: certificate,
        account: organization1.default_account,
        status: 'intransit',
        to_organization: organization2,
        intransit_at: 1.hour.ago
      )
      
      expect { described_class.perform_now }
        .not_to change { fresh_transfer.reload.status }
    end

    it 'ignores non-intransit records' do
      # Create an active record (should be ignored)
      active_transfer = create(:certificate_quantity,
        certificate: certificate,
        account: organization1.default_account,
        status: 'active',
        intransit_at: 25.hours.ago
      )
      
      # Create a retired record (should be ignored)  
      retired_transfer = create(:certificate_quantity,
        certificate: certificate,
        account: organization1.default_account,
        status: 'retired',
        intransit_at: 25.hours.ago
      )
      
      described_class.perform_now
      
      expect(active_transfer.reload.status).to eq('active')
      expect(retired_transfer.reload.status).to eq('retired')
    end
  end
end

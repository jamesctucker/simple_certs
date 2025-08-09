require 'rails_helper'

RSpec.describe CertificateQuantity, type: :model do
  let(:organization) { create(:organization) }
  let(:generator) { create(:generator, organization: organization) }
  let(:generation) { create(:generation, generator: generator) }
  let(:certificate) { create(:certificate, generator: generator, generation: generation) }
  let(:other_org) { create(:organization) }
  
  describe '#cancel_transfer!' do
    it 'resets intransit record to active and clears transfer fields' do
      cert_qty = create(:certificate_quantity,
        certificate: certificate,
        account: organization.default_account,
        status: 'intransit',
        to_organization: other_org,
        intransit_at: 1.hour.ago
      )
      
      cert_qty.cancel_transfer!
      
      expect(cert_qty.status).to eq('active')
      expect(cert_qty.to_organization).to be_nil
      expect(cert_qty.intransit_at).to be_nil
    end
    
    it 'does nothing if record is not intransit' do
      cert_qty = create(:certificate_quantity,
        certificate: certificate,
        account: organization.default_account,
        status: 'active'
      )
      
      expect { cert_qty.cancel_transfer! }.not_to change { cert_qty.reload.status }
    end
  end
end

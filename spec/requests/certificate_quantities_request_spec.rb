require 'rails_helper'

RSpec.describe 'CertificateQuantities', type: :request do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:account) { organization.default_account }
  let(:other_account) { other_organization.default_account }
  let(:account2) { create(:account, organization: organization) }
  let(:other_account2) { create(:account, organization: other_organization) }
  let(:user) { create(:user, organization: organization) }
  let(:other_user) { create(:user, organization: other_organization) }
  let(:generator) { create(:generator, organization: organization) }
  let(:other_generator) { create(:generator, organization: other_organization) }
  let!(:generation) { create(:generation, generator: generator) }
  let!(:other_generation) { create(:generation, generator: other_generator) }
  let(:certificate) { generation.certificate }
  let(:other_certificate) { other_generation.certificate }
  let(:certificate_quantity) { certificate.reload.certificate_quantities.first }
  let(:other_certificate_quantity) { other_certificate.reload.certificate_quantities.first }
  let(:generation_in_transit) { create(:generation, generator: other_generator) }
  let(:certificate_in_transit) { generation_in_transit.certificate }
  let(:certificate_quantity_in_transit) { certificate_in_transit.certificate_quantities.first }

  let(:json_headers) {
    { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
  }
  let(:user_header) {
    { 'X-Api-Key' => user.api_key }
  }
  let(:headers) {
    json_headers.merge(user_header)
  }

  def certificate_quantity_json(certificate_quantity)
    json = {
      'id' => certificate_quantity.id,
      'quantity' => certificate_quantity.quantity,
      'certificate_id' => certificate_quantity.certificate_id,
      'account_id' => certificate_quantity.account_id,
      'status' => certificate_quantity.status
    }
    if certificate_quantity.status == 'intransit'
      json.merge!({
        'to_organization_id' => certificate_quantity.to_organization_id,
        'intransit_at' => certificate_quantity.intransit_at&.as_json
      })
    end
    json
  end

  context 'index' do
    before do
      certificate_quantity_in_transit.update(status: 'intransit', to_organization: organization)
      get '/certificate_quantities', headers: headers
    end

    it 'has a 200 status' do
      expect(response.status).to eq(200)
    end

    it 'returns certificate quantities' do
      json = JSON.parse(response.body)
      expect(json['certificate_quantities']).to match_array([
        certificate_quantity_json(certificate_quantity),
        certificate_quantity_json(certificate_quantity_in_transit)
      ])
    end
  end

  context 'show' do
    context "when accessing certificate quantity that is associated with user's organization" do
      it 'returns a certificate quantity' do
        get "/certificate_quantities/#{certificate_quantity.id}", headers: headers
        json = JSON.parse(response.body)
        expect(json).to eq(certificate_quantity_json(certificate_quantity))
      end
    end

    context "when accessing certificate quantity that is not associated with user's organization" do
      it 'returns an unauthorized status' do
        get "/certificate_quantities/#{other_certificate_quantity.id}", headers: headers
        expect(response.code).to eq('401')
      end
    end
  end

  context 'retire' do
    context "when retiring a certificate that is associated with the user's organization" do
      before do
        put "/certificate_quantities/#{certificate_quantity.id}/retire", headers: headers
      end

      it 'returns a 200 status' do
        expect(response.code).to eq('200')
      end

      it 'responds with the updated certificate status' do
        json = JSON.parse(response.body)
        expect(json).to eq(certificate_quantity_json(certificate_quantity.reload))
      end

      it 'modifies the certificate status to retired' do
        expect(certificate_quantity.reload.status).to eq('retired')
      end
    end

    context "when retiring a certificate that is active" do
      it 'returns an unprocessable entity status' do
        certificate_quantity.update(status: 'retired')
        put "/certificate_quantities/#{certificate_quantity.id}/retire", headers: headers
        expect(response.code).to eq('422')
      end
    end

    context "when retiring a certificate that is not associated with the user's organization" do
      it 'returns an unauthorized status' do
        put "/certificate_quantities/#{other_certificate_quantity.id}/retire", headers: headers
        expect(response.code).to eq('401')
      end
    end
  end

  context 'transfer' do
    context "when transferring a certificate to another account that is associated with the user's organization" do
      before do
        put "/certificate_quantities/#{certificate_quantity.id}/transfer?account_id=#{account2.id}", headers: headers
      end

      it 'returns a 200 status' do
        expect(response.code).to eq('200')
      end

      it 'responds with the updated certificate status' do
        json = JSON.parse(response.body)
        expect(json).to eq(certificate_quantity_json(certificate_quantity.reload))
      end

      it 'modifies the certificate account to change to passed in account' do
        expect(certificate_quantity.reload.account).to eq(account2)
      end

      it 'does not set intransit_at when transferring to account within organization' do
        put "/certificate_quantities/#{certificate_quantity.id}/transfer?account_id=#{account2.id}", headers: headers

        certificate_quantity.reload
        expect(certificate_quantity.intransit_at).to be_nil
        expect(certificate_quantity.status).to eq('active')
      end
    end

    context "when transferring a certificate to another organization that is associated with the user's organization" do
      before do
        put "/certificate_quantities/#{certificate_quantity.id}/transfer?organization_id=#{other_organization.id}", headers: headers
      end

      it 'returns a 200 status' do
        expect(response.code).to eq('200')
      end

      it 'responds with the updated certificate status' do
        json = JSON.parse(response.body)
        expect(json).to eq(certificate_quantity_json(certificate_quantity.reload))
      end

      it 'modifies the certificate status to intransit' do
        expect(certificate_quantity.reload.status).to eq('intransit')
      end

      it 'modifies the to_organization' do
        expect(certificate_quantity.reload.to_organization).to eq(other_organization)
      end

      it 'sets intransit_at timestamp when transferring to organization' do
        put "/certificate_quantities/#{certificate_quantity.id}/transfer?organization_id=#{other_organization.id}", headers: headers

        certificate_quantity.reload
        expect(certificate_quantity.intransit_at).to be_present
      end
    end

    context "when passing invalid parameters" do
      it "returns an unprocessable_entity status when an account_id and organization_id are both passed in" do
        put "/certificate_quantities/#{certificate_quantity.id}/transfer?account_id=1&organization_id=2", headers: headers
        expect(response.code).to eq('422')
      end

      it "returns an unprocessable_entity status when the account is not the user's organization's account" do
        put "/certificate_quantities/#{certificate_quantity.id}/transfer?account_id=#{other_account.id}", headers: headers
        expect(response.code).to eq('422')
      end

      it "returns an unprocessable_entity status when the certificate quantity is already retired" do
        certificate_quantity.update(status: 'retired')
        put "/certificate_quantities/#{certificate_quantity.id}/transfer?account_id=#{account2.id}", headers: headers
        expect(response.code).to eq('422')
      end

      it "returns an unprocessable_entity status when the certificate quantity is already intransit" do
        certificate_quantity.update(status: 'intransit')
        put "/certificate_quantities/#{certificate_quantity.id}/transfer?account_id=#{account2.id}", headers: headers
        expect(response.code).to eq('422')
      end

      it "returns an unprocessable_entity status when the organization_id is the user's organization ID" do
        put "/certificate_quantities/#{certificate_quantity.id}/transfer?organization_id=#{user.organization.id}", headers: headers
        expect(response.code).to eq('422')
      end

      it "returns an unprocessable_entity status when the organization_id is a valid organization ID" do
        put "/certificate_quantities/#{certificate_quantity.id}/transfer?organization_id=1000", headers: headers
        expect(response.code).to eq('422')
      end
    end

    context "when transferring a certificate that is not associated with the user's organization" do
      it 'returns an unauthorized status' do
        put "/certificate_quantities/#{other_certificate_quantity.id}/transfer", headers: headers
        expect(response.code).to eq('401')
      end
    end
  end

  context 'cancel_transfer' do
    context "when cancelling a transfer that is associated with the user's organization" do
      before do
        certificate_quantity.update!(status: 'intransit', to_organization: other_organization, intransit_at: 1.hour.ago)
      end

      def do_request
        put "/certificate_quantities/#{certificate_quantity.id}/cancel_transfer", headers: headers
      end

      it 'returns a 200 status' do
        do_request
        expect(response).to have_http_status(:ok)
      end

      it 'clears intransit_at' do
        do_request
        expect(certificate_quantity.reload.intransit_at).to be_nil
      end

      it 'clears to_organization' do
        do_request
        expect(certificate_quantity.reload.to_organization).to be_nil
      end
    end

    context 'when the status is not intransit' do
      it 'returns a unprocessable_entity status' do
        certificate_quantity.update(status: 'active')
        put "/certificate_quantities/#{certificate_quantity.id}/cancel_transfer", headers: headers
        expect(response.code).to eq('422')
      end
    end

    context "when canceling a transfer of a certificate to another organization that is associated with the user's organization" do
      before do
        certificate_quantity.update(status: 'intransit', to_organization: other_organization)
        put "/certificate_quantities/#{certificate_quantity.id}/cancel_transfer", headers: headers
      end

      it 'returns a 200 status' do
        expect(response.code).to eq('200')
      end

      it 'responds with the updated certificate status' do
        json = JSON.parse(response.body)
        expect(json).to eq(certificate_quantity_json(certificate_quantity.reload))
      end

      it 'returns the certificate status as active' do
        expect(certificate_quantity.reload.status).to eq('active')
      end

      it 'resets the to_organization' do
        expect(certificate_quantity.reload.to_organization).to be_nil
      end
    end

    context "when transferring a certificate that is not associated with the user's organization" do
      before do
        certificate_quantity.update(status: 'intransit', to_organization: other_organization)
        put "/certificate_quantities/#{other_certificate_quantity.id}/transfer", headers: headers
      end

      it 'returns an unauthorized status' do
        expect(response.code).to eq('401')
      end

      it 'leaves the certificate status as intransit' do
        expect(certificate_quantity.reload.status).to eq('intransit')
      end

      it 'leaves the to_organization' do
        expect(certificate_quantity.reload.to_organization).to eq(other_organization)
      end
    end
  end

  context 'accept_transfer' do
    let(:user_header) { { 'X-Api-Key' => other_user.api_key } }
    let(:other_headers) { json_headers.merge(user_header) }

    before do
      certificate_quantity.update!(status: 'intransit', to_organization: other_organization, intransit_at: 1.hour.ago)
    end

    def do_request
      put "/certificate_quantities/#{certificate_quantity.id}/accept_transfer", headers: other_headers
    end

    it 'returns a 200 status' do
      do_request
      expect(response).to have_http_status(:ok)
    end

    it 'clears intransit_at' do
      do_request
      expect(certificate_quantity.reload.intransit_at).to be_nil
    end
  end

  context 'split' do
    context "when splitting a certificate that is associated with the user's organization" do
      before do
        put "/certificate_quantities/#{certificate_quantity.id}/split?quantity=99", headers: headers
      end

      it 'returns a 200 status' do
        expect(response.code).to eq('200')
      end

      it 'responds with the updated certificate status' do
        json = JSON.parse(response.body)
        expect(json).to eq(certificate_quantity_json(certificate_quantity.reload))
      end

      it 'modifies the certificate account to change to passed in account' do
        expect(certificate_quantity.reload.quantity).to eq(99)
      end

      it 'creates a new certificate with the left over quantity' do
        expect(certificate_quantity.certificate.reload.certificate_quantities.map(&:quantity)).to match_array([ 1, 99 ])
      end

      it 'creates a new certificate with the same account' do
        expect(certificate_quantity.certificate.reload.certificate_quantities.map(&:account)).to match_array([ account, account ])
      end

      it 'creates a new certificate with an active status' do
        expect(certificate_quantity.certificate.reload.certificate_quantities.map(&:status)).to match_array([ 'active', 'active' ])
      end
    end

    context "when splitting a certificate with an non-numeric quantity" do
      it 'returns a unprocessable_entity status' do
        put "/certificate_quantities/#{certificate_quantity.id}/split?quantity=abc", headers: headers
        expect(response.code).to eq('422')
      end
    end

    context "when splitting a certificate with an a too large quantity" do
      it 'returns a unprocessable_entity status' do
        put "/certificate_quantities/#{certificate_quantity.id}/split?quantity=1000", headers: headers
        expect(response.code).to eq('422')
      end
    end

    context "when splitting a certificate with an a exact same quantity" do
      it 'returns a unprocessable_entity status' do
        put "/certificate_quantities/#{certificate_quantity.id}/split?quantity=100", headers: headers
        expect(response.code).to eq('422')
      end
    end

    context "when splitting a certificate with a intransit status" do
      it 'returns a unprocessable_entity status' do
        certificate_quantity.update(status: 'intransit')
        put "/certificate_quantities/#{certificate_quantity.id}/split?quantity=1", headers: headers
        expect(response.code).to eq('422')
      end
    end

    context "when splitting a certificate with a retired status" do
      it 'returns a unprocessable_entity status' do
        certificate_quantity.update(status: 'retired')
        put "/certificate_quantities/#{certificate_quantity.id}/split?quantity=1", headers: headers
        expect(response.code).to eq('422')
      end
    end

    context "when splitting a certificate that is not associated with the user's organization" do
      it 'returns an unauthorized status' do
        put "/certificate_quantities/#{other_certificate_quantity.id}/split?quantity=2", headers: headers
        expect(response.code).to eq('401')
      end
    end
  end
end

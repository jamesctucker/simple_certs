class CertificateQuantity < ApplicationRecord
  belongs_to :certificate
  belongs_to :account
  belongs_to :to_organization, class_name: "Organization", foreign_key: "to_organization_id", optional: true

  def split(quantity)
    self.class.create(certificate: certificate, account: account, quantity: self.quantity - quantity, status: "active")
    update(quantity: quantity)
  end

  def retire
    update(status: "retired")
  end

  def cancel_transfer!
    return unless status == "intransit"
    
    update!(status: "active", to_organization: nil, intransit_at: nil)
  end

  def accept_transfer!(recipient_account)
    return unless status == "intransit"
    
    update!(status: "active", to_organization: nil, account: recipient_account, intransit_at: nil)
  end
end

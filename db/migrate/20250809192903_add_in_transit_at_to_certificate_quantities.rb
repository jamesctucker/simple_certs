class AddInTransitAtToCertificateQuantities < ActiveRecord::Migration[8.0]
  def change
    add_column :certificate_quantities, :intransit_at, :datetime
    add_index :certificate_quantities, :intransit_at
  end
end

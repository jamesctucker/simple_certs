json.id certificate_quantity.id
json.quantity certificate_quantity.quantity
json.certificate_id certificate_quantity.certificate_id
json.account_id certificate_quantity.account_id
json.to_organization_id certificate_quantity.to_organization_id if certificate_quantity.status == "intransit"
json.status certificate_quantity.status
json.intransit_at certificate_quantity.intransit_at if certificate_quantity.status == "intransit"

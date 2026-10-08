# Mirrors app/frontend/types/bonds.ts (Issuer, IssuerSummary, IssuerDetail).
class IssuerSerializer
  def self.summary(issuer, outstanding_principal_cents:)
    base(issuer).merge(outstanding_principal_cents:)
  end

  # Expects bonds and their payments preloaded (see Api::IssuersController#show).
  def self.detail(issuer)
    base(issuer).merge(bonds: issuer.bonds.map { |bond| BondSerializer.with_schedule(bond) })
  end

  def self.base(issuer)
    { id: issuer.id, name: issuer.name, issuer_type: issuer.issuer_type, state: issuer.state }
  end
end

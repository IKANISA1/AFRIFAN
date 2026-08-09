/// Explicit PostgREST projections for the supporter membership boundary.
///
/// Keeping these lists aligned with the granted column ACLs avoids accidental
/// reliance on `select('*')` as the schema evolves.
abstract final class MembershipReadProjection {
  static const String fanMembership =
      'id,user_id,partner_id,club_id,tier,points,joined_at,chapter,'
      'membership_number,display_name,expires_at,renewed_at,payment_status,'
      'status,created_at,updated_at';

  static const String application =
      'id,user_id,club_id,tier,status,payment_status,application_date,'
      'review_date,reviewer_id,notes,metadata,created_at,updated_at';

  static const String tier =
      'id,partner_id,club_id,tier,category_slug,title,name,subtitle,'
      'description,benefits,annual_price,price,is_active,active,sort_order,'
      'benefit_scope,store_billing_required,created_at,updated_at';
}

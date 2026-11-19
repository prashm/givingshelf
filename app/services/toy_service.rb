class ToyService < ItemService
  def search_items(base_scope: Toy.available, query_string: nil, zip_code: nil, radius: nil, community_group_id: nil, sub_group_id: nil, age_range: nil, user_join_type: :owner)
    super(
      base_scope: base_scope,
      query_string: query_string,
      zip_code: zip_code,
      radius: radius,
      community_group_id: community_group_id,
      sub_group_id: sub_group_id,
      age_range: age_range,
      user_join_type: user_join_type
    )
  end

  private

  def type_fields(toy, detail:)
    {
      brand: toy.brand,
      age_range: toy.age_range,
      age_range_display: ToyAgeRange.display_age_range(toy.age_range),
      min_age: toy.min_age,
      max_age: toy.max_age
    }
  end

  def type_class
    Toy
  end
end

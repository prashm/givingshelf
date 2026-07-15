class BackfillToyMinMaxAge < ActiveRecord::Migration[8.0]
  def up
    Toy.where.not(age_range: [ nil, "" ]).find_each do |toy|
      parsed = ToyAgeRange.parse(toy.age_range)
      if parsed
        toy.update_columns(min_age: parsed[:min], max_age: parsed[:max])
      else
        toy.update_columns(min_age: nil, max_age: nil)
      end
    end
  end

  def down
    Toy.update_all(min_age: nil, max_age: nil)
  end
end

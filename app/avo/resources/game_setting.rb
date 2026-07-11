class Avo::Resources::GameSetting < Avo::BaseResource
  self.title = :id

  def fields
    field :id, as: :id
    field :heart_drop_chance, as: :number, step: 0.01
    field :rewind_drop_chance, as: :number, step: 0.01
    field :updated_at, as: :date_time, readonly: true, only_on: :show
  end
end

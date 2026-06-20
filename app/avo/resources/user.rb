class Avo::Resources::User < Avo::BaseResource
  self.title = :username

  def fields
    field :id, as: :id
    field :email_address, as: :text
    field :username, as: :text
    field :super_admin, as: :boolean
    field :confirmed_at, as: :date_time, readonly: true
    field :totp_enabled, as: :boolean, readonly: true
    field :highest_level_completed, as: :number, readonly: true
    field :now_playing_level, as: :number, readonly: true
    field :created_at, as: :date_time, readonly: true, only_on: :show
    field :earned_achievements, as: :has_many
  end

  def actions
    action Avo::Actions::ResetProgress
  end
end

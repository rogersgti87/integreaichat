# frozen_string_literal: true

class InternalChat::SearchUsers
  pattr_initialize [:account!, :query, :exclude_user_id]

  def perform
    scope = account.users.order('users.name ASC')
    scope = scope.where.not(users: { id: exclude_user_id }) if exclude_user_id.present?

    if query.present?
      sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(query.strip)}%"
      scope = scope.where('users.name ILIKE :q OR users.email ILIKE :q', q: sanitized)
    end

    scope.limit(200)
  end
end

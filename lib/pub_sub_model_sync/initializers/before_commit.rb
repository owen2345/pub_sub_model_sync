# frozen_string_literal: true

# Rails 4 backward compatibility (Add "simple" ps_before_*_commit callbacks)
ActiveRecord::ConnectionAdapters::RealTransaction.class_eval do
  alias_method :commit_with_before_commit, :commit

  def commit
    call_before_commit_records if Rails::VERSION::MAJOR == 4
    commit_with_before_commit
  end

  private

  def call_before_commit_records
    ite = records.uniq
    ite.each do |record|
      action = record.previous_changes.include?(:id) ? :create : :update
      action = :destroy if record.destroyed?
      callback_name = "ps_before_#{action}_commit".to_sym
      record.send(callback_name) if record.respond_to?(callback_name)
    end
  end
end

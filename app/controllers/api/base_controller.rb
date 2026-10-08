module Api
  # Every API error leaves the app in one shape: { errors: { field: ["message"] } }.
  # The React client reads that one shape and renders it next to the right form field.
  class BaseController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound do |error|
      render json: { errors: { base: ["#{error.model} not found"] } }, status: :not_found
    end

    rescue_from ActiveRecord::RecordInvalid do |error|
      render json: { errors: error.record.errors.to_hash }, status: :unprocessable_content
    end

    rescue_from ActionController::ParameterMissing do |error|
      render json: { errors: { error.param => ["is required"] } }, status: :bad_request
    end

    # A race past the uniqueness validation still hits the unique index. Report it like a validation error.
    rescue_from ActiveRecord::RecordNotUnique do
      render json: { errors: { base: ["already exists"] } }, status: :unprocessable_content
    end
  end
end

# frozen_string_literal: true

require "rubocop"
require_relative "tsurakunai/rails/version"
require_relative "rubocop/tsurakunai_rails/plugin"
require_relative "rubocop/cop/tsurakunai_rails/controller_callbacks"
require_relative "rubocop/cop/tsurakunai_rails/default_scope"
require_relative "rubocop/cop/tsurakunai_rails/validation_bypass"
require_relative "rubocop/cop/tsurakunai_rails/model_request_context"
require_relative "rubocop/cop/tsurakunai_rails/model_callbacks"
require_relative "rubocop/cop/tsurakunai_rails/implicit_context"
require_relative "rubocop/cop/tsurakunai_rails/concern"

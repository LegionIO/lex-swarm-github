# frozen_string_literal: true

return unless defined?(Legion::Extensions::Actors::Subscription)

module Legion
  module Extensions
    module SwarmGithub
      module Actor
        class LifecycleSubscriber < Legion::Extensions::Actors::Subscription
          def runner_class    = self.class
          def runner_function = 'action'
          def check_subtask?  = true
          def generate_task?  = false

          def action(payload)
            verdict = (payload[:verdict] || payload['verdict']).to_s

            unless verdict == 'approve' && github_lifecycle_enabled?
              return { skipped: true, reason: verdict == 'approve' ? :github_disabled : :not_approved }
            end

            generation = payload[:generation] || payload['generation'] || {}
            review = payload.except(:generation, 'generation')
            review_k = payload[:review_k] || payload['review_k']
            raw_models = payload[:review_models] || payload['review_models']
            review_models = normalize_review_models(raw_models)

            Runners::ExtensionLifecycle.run_lifecycle(generation: generation, review: review,
                                                      review_k: review_k, review_models: review_models)
          rescue StandardError => e
            log.warn("LifecycleSubscriber failed: #{e.message}")
            { success: false, error: e.message }
          end

          private

          def normalize_review_models(raw)
            return nil unless raw.is_a?(Array)

            raw.filter_map do |spec|
              next unless spec.is_a?(Hash)

              spec.transform_keys { |k| k.respond_to?(:to_sym) ? k.to_sym : k }
            end
          end

          def github_lifecycle_enabled?
            return false unless defined?(Legion::Settings)

            Legion::Settings.dig(:codegen, :self_generate, :github, :enabled) == true
          rescue StandardError => e
            log.warn(e.message)
            false
          end

          def log
            return Legion::Logging if defined?(Legion::Logging)

            @log ||= Object.new.tap do |nl|
              %i[debug info warn error fatal].each { |m| nl.define_singleton_method(m) { |*| nil } }
            end
          end
        end
      end
    end
  end
end

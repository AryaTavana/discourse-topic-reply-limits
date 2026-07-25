# frozen_string_literal: true

module DiscourseTopicReplyLimits
  module Admin
    class EntitlementsController < ::Admin::AdminController
      requires_plugin PLUGIN_NAME

      before_action :ensure_admin

      def sync
        Entitlements::Sync.call(
          service_params.merge(params: entitlement_params)
        ) do
          on_success { |result:| render json: success_json.merge(result) }
          on_failed_policy(:can_sync_entitlements) do
            raise Discourse::InvalidAccess
          end
          on_failed_contract do |contract|
            render(
              json: failed_json.merge(errors: contract.errors.full_messages),
              status: :bad_request
            )
          end
          on_failure do |error_message: nil|
            render_json_error(
              error_message ||
                I18n.t(
                  "discourse_topic_reply_limits.errors.entitlement_sync_failed"
                ),
              status: :unprocessable_entity
            )
          end
        end
      end

      private

      def entitlement_params
        permitted =
          params.permit(
            entitlements: %i[
              user_external_id
              entitlement_id
              group_name
              starts_at
              ends_at
            ]
          )

        {
          entitlements:
            permitted[:entitlements].to_a.map do |item|
              item.to_h.to_hash.symbolize_keys
            end
        }
      end
    end
  end
end

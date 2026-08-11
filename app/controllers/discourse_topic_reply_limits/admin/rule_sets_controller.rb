# frozen_string_literal: true

module DiscourseTopicReplyLimits
  module Admin
    class RuleSetsController < ::Admin::AdminController
      requires_plugin PLUGIN_NAME

      before_action :ensure_admin

      def index
        rules =
          Rule
            .includes(:group, :topic)
            .to_a
            .reject { |rule| rule.topic.deleted_at.present? }
        collections =
          rules
            .group_by(&:topic)
            .map do |topic, topic_rules|
              RuleCollection.new(topic:, rules: topic_rules.sort_by(&:group_id))
            end
            .sort_by { |collection| collection.topic.title.downcase }

        render json: {
                 rule_sets:
                   collections.map do |collection|
                     RuleSetSerializer.new(
                       collection,
                       scope: guardian,
                       root: false
                     ).as_json
                   end
               }
      end

      def show
        collection = collection_for(params[:topic_id])
        render json: {
                 rule_set:
                   RuleSetSerializer.new(
                     collection,
                     scope: guardian,
                     root: false
                   ).as_json
               }
      end

      def create
        upsert_rule_set(status: :created)
      end

      def update
        payload = rule_set_params.merge(topic_id: params[:topic_id])
        upsert_rule_set(payload:, status: :ok)
      end

      def destroy
        RuleSet::Destroy.call(
          service_params.deep_merge(params: { topic_id: params[:topic_id] })
        ) do
          on_success { head :no_content }
          on_failed_policy(:can_manage_reply_limits) do
            raise Discourse::InvalidAccess
          end
          on_model_not_found(:topic) { raise Discourse::NotFound }
          on_model_not_found(:rules) { raise Discourse::NotFound }
          on_failed_contract { |contract| render_contract_errors(contract) }
          on_failure { render json: failed_json, status: :unprocessable_entity }
        end
      end

      private

      def upsert_rule_set(payload: rule_set_params, status:)
        service_input =
          service_params.deep_merge(params: payload).deep_symbolize_keys

        RuleSet::Upsert.call(service_input) do
          on_success do |topic:|
            collection = collection_for(topic.id)
            render json: {
                     rule_set:
                       RuleSetSerializer.new(
                         collection,
                         scope: guardian,
                         root: false
                       ).as_json
                   },
                   status:
          end
          on_failed_policy(:can_manage_reply_limits) do
            raise Discourse::InvalidAccess
          end
          on_model_not_found(:topic) { raise Discourse::NotFound }
          on_model_not_found(:groups) do
            render_json_error(
              I18n.t("discourse_topic_reply_limits.errors.invalid_groups")
            )
          end
          on_failed_contract { |contract| render_contract_errors(contract) }
          on_failure { render json: failed_json, status: :unprocessable_entity }
        end
      end

      def rule_set_params
        permitted =
          params.require(:rule_set).permit(
            :topic_id,
            assignments: %i[
              group_id
              reply_limit
              warning_percentage
              carryover_limit
            ]
          )

        {
          topic_id: permitted[:topic_id],
          assignments:
            permitted[:assignments].to_a.map do |assignment|
              assignment.to_h.to_a.to_h.transform_keys(&:to_sym)
            end
        }
      end

      def collection_for(topic_id)
        topic = Topic.find_by(id: topic_id, archetype: Archetype.default)
        raise Discourse::NotFound if topic.blank?

        rules =
          Rule.includes(:group).where(topic_id: topic.id).order(:group_id).to_a
        raise Discourse::NotFound if rules.empty?

        RuleCollection.new(topic:, rules:)
      end

      def render_contract_errors(contract)
        render(
          json: failed_json.merge(errors: contract.errors.full_messages),
          status: :bad_request
        )
      end
    end
  end
end

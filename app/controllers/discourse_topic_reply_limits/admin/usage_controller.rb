# frozen_string_literal: true

module DiscourseTopicReplyLimits
  module Admin
    class UsageController < ::Admin::AdminController
      requires_plugin PLUGIN_NAME

      before_action :ensure_admin

      def index
        report =
          UsageReport.new(
            page: params[:page],
            per_page: params[:per_page],
            query: params[:q]
          ).call

        render json: report
      end
    end
  end
end

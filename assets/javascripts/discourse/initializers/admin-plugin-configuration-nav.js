import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-topic-reply-limits";

export default {
  name: "topic-reply-limits-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "gauge-high");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "discourse_topic_reply_limits.admin.rules.title",
          route: "adminPlugins.show.topic-reply-limits",
          description:
            "discourse_topic_reply_limits.admin.rules.description",
        },
      ]);
    });
  },
};

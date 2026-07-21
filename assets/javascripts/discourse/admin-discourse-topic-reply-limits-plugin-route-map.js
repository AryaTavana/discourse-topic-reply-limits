export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",

  map() {
    this.route("topic-reply-limits", { path: "reply-limits" }, function () {
      this.route("new");
      this.route("edit", { path: "/:topic_id/edit" });
    });
  },
};

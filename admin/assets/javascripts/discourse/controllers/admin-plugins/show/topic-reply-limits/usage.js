import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminPluginsShowTopicReplyLimitsUsageController extends Controller {
  @tracked report;
  @tracked query = "";
  @tracked loading = false;

  initializeReport(report) {
    this.report = report;
    this.query = report.meta.query;
  }

  get hasQuery() {
    return this.report.meta.query.length > 0;
  }

  get previousDisabled() {
    return !this.report.meta.has_previous || this.loading;
  }

  get nextDisabled() {
    return !this.report.meta.has_more || this.loading;
  }

  @action
  updateQuery(event) {
    this.query = event.target.value;
  }

  @action
  search(event) {
    event?.preventDefault();
    return this.loadPage(1, this.query);
  }

  @action
  clearSearch() {
    this.query = "";
    return this.loadPage(1, "");
  }

  @action
  previousPage() {
    return this.loadPage(this.report.meta.page - 1);
  }

  @action
  nextPage() {
    return this.loadPage(this.report.meta.page + 1);
  }

  async loadPage(page, query = this.report.meta.query) {
    this.loading = true;

    try {
      this.report = await ajax(
        "/admin/plugins/discourse-topic-reply-limits/usage.json",
        {
          data: {
            page,
            q: query.trim(),
          },
        }
      );
      this.query = this.report.meta.query;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }
}

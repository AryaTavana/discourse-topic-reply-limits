import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { gt } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import TopicReplyLimitTopicSelector from "./topic-reply-limit-topic-selector";

export default class TopicReplyLimitRuleSetForm extends Component {
  @service router;
  @service site;
  @service toasts;

  get groups() {
    return this.site.groups;
  }

  get submitLabel() {
    return this.args.editing
      ? "discourse_topic_reply_limits.admin.form.update"
      : "discourse_topic_reply_limits.admin.form.create";
  }

  @action
  setGroup(field, value) {
    field.set(Array.isArray(value) ? value[0] : value);
  }

  @action
  async save(data) {
    const topicId = this.args.editing ? this.args.model.topic_id : data.topic_id;
    const url = this.args.editing
      ? `/admin/plugins/discourse-topic-reply-limits/rule-sets/${topicId}.json`
      : "/admin/plugins/discourse-topic-reply-limits/rule-sets.json";

    try {
      await ajax(url, {
        type: this.args.editing ? "PUT" : "POST",
        contentType: "application/json",
        data: JSON.stringify({
          rule_set: { topic_id: topicId, assignments: data.assignments },
        }),
      });
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n(
            this.args.editing
              ? "discourse_topic_reply_limits.admin.form.update_success"
              : "discourse_topic_reply_limits.admin.form.create_success"
          ),
        },
      });
      this.router.transitionTo("adminPlugins.show.topic-reply-limits");
    } catch (error) {
      popupAjaxError(error);
      throw error;
    }
  }

  <template>
    <Form
      @data={{@model}}
      @onSubmit={{this.save}}
      class="topic-reply-limit-form"
      as |form data|
    >
      <form.Section
        @title={{i18n "discourse_topic_reply_limits.admin.form.topic_section"}}
      >
        {{#if @editing}}
          <form.Container
            @title={{i18n "discourse_topic_reply_limits.admin.form.topic"}}
          >
            <a href={{@model.topic_url}}>{{@model.topic_title}}</a>
          </form.Container>
        {{else}}
          <form.Field
            @name="topic_id"
            @title={{i18n "discourse_topic_reply_limits.admin.form.topic"}}
            @description={{i18n
              "discourse_topic_reply_limits.admin.form.topic_help"
            }}
            @type="custom"
            @validation="required"
            as |field|
          >
            <field.Control>
              <TopicReplyLimitTopicSelector
                @value={{field.value}}
                @onChange={{field.set}}
              />
            </field.Control>
          </form.Field>
        {{/if}}
      </form.Section>

      <form.Section
        @title={{i18n "discourse_topic_reply_limits.admin.form.limits_section"}}
        @subtitle={{i18n
          "discourse_topic_reply_limits.admin.form.limits_help"
        }}
      >
        <form.Collection @name="assignments" as |collection index|>
          <form.Container class="topic-reply-limit-form__assignment">
            <form.Row>
              <collection.Field
                @name="group_id"
                @title={{i18n
                  "discourse_topic_reply_limits.admin.form.group"
                }}
                @type="custom"
                @validation="required"
                as |field|
              >
                <field.Control>
                  <GroupChooser
                    @value={{field.value}}
                    @content={{this.groups}}
                    @labelProperty="name"
                    @onChange={{fn this.setGroup field}}
                    @options={{hash maximum=1}}
                  />
                </field.Control>
              </collection.Field>

              <collection.Field
                @name="reply_limit"
                @title={{i18n
                  "discourse_topic_reply_limits.admin.form.reply_limit"
                }}
                @type="input-number"
                @validation="required|number|integer|between:1,1000000"
                as |field|
              >
                <field.Control min="1" max="1000000" />
              </collection.Field>

              <collection.Field
                @name="warning_percentage"
                @title={{i18n
                  "discourse_topic_reply_limits.admin.form.warning_percentage"
                }}
                @type="input-number"
                @validation="required|number|integer|between:1,99"
                as |field|
              >
                <field.Control min="1" max="99" />
              </collection.Field>
            </form.Row>

            {{#if (gt data.assignments.length 1)}}
              <form.Button
                @icon="trash-can"
                @label="discourse_topic_reply_limits.admin.form.remove_group"
                @action={{fn collection.remove index}}
                class="btn-danger topic-reply-limit-form__remove"
              />
            {{/if}}
          </form.Container>
        </form.Collection>

        <form.Button
          @icon="plus"
          @label="discourse_topic_reply_limits.admin.form.add_group"
          @action={{fn
            form.addItemToCollection
            "assignments"
            (hash group_id=null reply_limit=5 warning_percentage=80)
          }}
          class="btn-default topic-reply-limit-form__add"
        />
      </form.Section>

      <form.Actions>
        <form.Submit @label={{this.submitLabel}} />
      </form.Actions>
    </Form>
  </template>
}

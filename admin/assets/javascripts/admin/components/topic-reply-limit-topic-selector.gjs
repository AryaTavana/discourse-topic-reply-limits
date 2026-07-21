import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import TopicChooser from "discourse/select-kit/components/topic-chooser";

export default class TopicReplyLimitTopicSelector extends Component {
  @tracked selectedTopic;

  get content() {
    return this.selectedTopic ? [this.selectedTopic] : [];
  }

  @action
  change(topicId, topic) {
    this.selectedTopic = topic;
    this.args.onChange(topicId);
  }

  <template>
    <TopicChooser
      @value={{@value}}
      @content={{this.content}}
      @onChange={{this.change}}
      @options={{hash castInteger=true}}
    />
  </template>
}

require 'test_helper'

class EventTest < ActiveSupport::TestCase
  
  def setup
    Page.delete_all
    @cal_node       = Node.root.children.create! :slug => "calendar"
    @draft          = find_or_create_draft(@cal_node, User.first)
    @draft.title    = "99C3"
    @draft.abstract = "The 99th Chaos Comunication Congress"
    @draft.body     = "Its totally freakin awesome"
    @draft.save
    @cal_node.publish_draft!
    @cal_node.head.reload
  end

  def event_entries
    NodeAction.where(:action => %w[event_create event_update event_destroy]).order(:id)
  end
  
  test 'verfy setup data' do 
    assert_not_nil @cal_node
    assert_not_nil @cal_node.head
  end
  
  test 'creating an event with malformed rrule raises exception' do
    assert_raise(ArgumentError) do
      Event.create!(
        :start_time   => "2009-01-01T15:23:42".to_time,
        :end_time     => "2009-01-01T20:05:23".to_time,
        :url          => "http://events.ccc.de/congress/2082",
        :latitude     => 52.525308,
        :longitude    => 13.378944,
        :rrule        => "FOOBAR",
        :allday       => false,
        :node_id      => @cal_node.id
      )
    end
  end
  
  test 'create day event for node with one occurrence' do
    assert_not_nil event = Event.create!(
      :start_time   => "2009-01-01T15:23:42".to_time,
      :end_time     => "2009-01-01T20:05:23".to_time,
      :url          => "http://events.ccc.de/congress/2082",
      :latitude     => 52.525308,
      :longitude    => 13.378944,
      :rrule        => nil,
      :allday       => false,
      :node_id      => @cal_node.id
    )
    
    assert_equal 1, Occurrence.count
    assert_equal event.start_time, Occurrence.first.start_time
    assert_equal event.end_time, Occurrence.first.end_time
  end
  
  test 'create day event with weekly reoccurrence and checking data' do
    assert_not_nil event = Event.create!(
      :start_time   => "2009-01-01T15:23:42".to_time,
      :end_time     => "2009-01-01T20:05:23".to_time,
      :url          => "http://events.ccc.de/congress/2082",
      :latitude     => 52.525308,
      :longitude    => 13.378944,
      :rrule        => "FREQ=WEEKLY;INTERVAL=1",
      :allday       => false,
      :node_id      => @cal_node.id
    )
    
    assert_not_nil scoped_occurrences = event.occurrences_in_range(
      "2009-01-01".to_time, "2009-12-31".to_time
    )
    
    assert_equal 52, scoped_occurrences.length
    
    assert_equal "2009-12-24T15:23:42".to_time, scoped_occurrences[51].start_time
    assert_equal "2009-12-24T20:05:23".to_time, scoped_occurrences[51].end_time
    assert_equal @cal_node.events.first, scoped_occurrences[51].event
    assert_equal @cal_node, scoped_occurrences[51].node
    
    assert_equal "2009-03-19T15:23:42".to_time, scoped_occurrences[11].start_time
    assert_equal "2009-03-19T20:05:23".to_time, scoped_occurrences[11].end_time
    assert_equal @cal_node.events.first, scoped_occurrences[11].event
    assert_equal @cal_node, scoped_occurrences[11].node
    
    assert_equal "2009-01-01T15:23:42".to_time, scoped_occurrences[0].start_time
    assert_equal "2009-01-01T20:05:23".to_time, scoped_occurrences[0].end_time
    assert_equal @cal_node.events.first, scoped_occurrences[11].event
    assert_equal @cal_node, scoped_occurrences[11].node
  end
  
  test 'create chaosradio event with custom rrule and interval' do
    assert_not_nil event = Event.create!(
      :start_time   => "2009-01-28T21:00:00".to_time,
      :end_time     => "2009-01-28T23:00:00".to_time,
      :url          => "http://chaosradio.ccc.de",
      :latitude     => 52.525308,
      :longitude    => 13.378944,
      :rrule        => "FREQ=MONTHLY;INTERVAL=1;BYDAY=-1WE",
      :allday       => false,
      :node_id      => @cal_node.id
    )
    
    assert_not_nil scoped_occurrences = event.occurrences_in_range(
      "2009-01-01".to_time, "2009-12-31".to_time 
    )
    
    assert_equal 12, scoped_occurrences.length
    
    expected_days = [28, 25, 25, 29, 27, 24, 29, 26, 30, 28, 25, 30]
    chaosradio_days = scoped_occurrences.map {|x| x.start_time.day}
    assert_equal expected_days, chaosradio_days
  end

  test "creating an event is witnessed with a full snapshot" do
    event = Event.new(:title => "Chaostreff",
                      :start_time => Time.utc(2026, 9, 1, 19, 0),
                      :end_time => Time.utc(2026, 9, 1, 21, 0),
                      :rrule => "FREQ=WEEKLY;BYDAY=TU", :location => "Zentrale",
                      :tag_list => "open-day")

    assert_difference -> { event_entries.count }, 1 do
      assert event.save_witnessed(:actor => users(:aaron))
    end

    entry = event_entries.last
    assert_equal "event_create", entry.action
    assert_equal users(:aaron).id, entry.user_id
    assert_equal "Chaostreff", entry.metadata["event_title"]
    assert_equal "FREQ=WEEKLY;BYDAY=TU", entry.metadata["rrule"]
    assert_equal ["open-day"], entry.metadata["event_tags"]
    assert_equal event.id, entry.action_participants.first.subject_id
    assert_equal "Event", entry.action_participants.first.subject_type
  end

  test "updating an event records only what changed" do
    event = Event.new(:title => "Chaostreff", :location => "Zentrale")
    event.save_witnessed(:actor => users(:aaron))

    assert_difference -> { event_entries.count }, 1 do
      assert event.update_witnessed({ :location => "Neue Zentrale" }, :actor => users(:aaron))
    end

    entry = event_entries.last
    assert_equal "event_update", entry.action
    assert_equal({ "from" => "Zentrale", "to" => "Neue Zentrale" },
                 entry.metadata.dig("changes", "location"))
    assert_nil entry.metadata.dig("changes", "title")
    assert_equal "Neue Zentrale", entry.metadata["location"]
  end

  test "an update that changes nothing records no entry" do
    event = Event.new(:title => "Chaostreff")
    event.save_witnessed(:actor => users(:aaron))

    assert_no_difference -> { event_entries.count } do
      assert event.update_witnessed({ :title => "Chaostreff" }, :actor => users(:aaron))
    end
  end

  test "deleting an event is witnessed before the row goes" do
    event = Event.new(:title => "Chaostreff", :location => "Zentrale")
    event.save_witnessed(:actor => users(:aaron))

    assert_difference -> { event_entries.count }, 1 do
      assert event.destroy_witnessed(:actor => users(:aaron))
    end

    entry = event_entries.last
    assert_equal "event_destroy", entry.action
    assert_equal "Chaostreff", entry.metadata["event_title"]
    assert_equal "Zentrale", entry.metadata["location"]
    assert_nil Event.find_by(:id => event.id)
  end

  test "an event may start without ending" do
    event = Event.new(:title => "Chaostreff", :start_time => Time.utc(2026, 9, 1, 19, 0))
    assert event.save
    assert_equal event.start_time, event.occurrences.first&.start_time
  end
end

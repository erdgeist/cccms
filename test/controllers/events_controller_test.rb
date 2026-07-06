require 'test_helper'

class EventsControllerTest < ActionController::TestCase

  test "should get index" do
    login_as :quentin
    node = create_node_with_published_page
    Event.create!(node_id: node.id, start_time: Time.now, end_time: Time.now + 1.hour)

    get :index
    assert_response :success
    assert_not_nil assigns(:events)
  end

  test "should get new" do
    login_as :quentin
    get :new
    assert_response :success
  end

  test "new pre-fills tag_list and explains it via flash when auto_tag_source is given" do
    login_as :quentin
    node = create_node_with_published_page

    get :new, params: { node_id: node.id, tag_list: "open-day", auto_tag_source: "erfa-detail" }

    assert_response :success
    assert_equal "open-day", assigns(:event).tag_list.to_s
    assert_match "open-day", flash[:notice]
    assert_match "erfa-detail", flash[:notice]
  end

  test "new does not flash without an auto_tag_source" do
    login_as :quentin

    get :new, params: { tag_list: "open-day" }

    assert_response :success
    assert_nil flash[:notice]
  end

  test "new with no params renders a blank, unflashed form" do
    login_as :quentin

    get :new

    assert_response :success
    assert_nil assigns(:event).tag_list.presence
    assert_nil flash[:notice]
  end

  test "should show event" do
    login_as :quentin
    node  = create_node_with_published_page
    event = Event.create!(node_id: node.id, start_time: Time.now, end_time: Time.now + 1.hour)

    get :show, params: { id: event.id }
    assert_response :success
  end

  test "should get edit" do
    login_as :quentin
    node  = create_node_with_published_page
    event = Event.create!(node_id: node.id, start_time: Time.now, end_time: Time.now + 1.hour)

    get :edit, params: { id: event.id }
    assert_response :success
  end

  test "should create event attached to a node" do
    login_as :quentin
    node = create_node_with_published_page

    assert_difference('Event.count') do
      post :create, params: {
        event: {
          node_id:    node.id,
          start_time: Time.now,
          end_time:   Time.now + 1.hour,
          tag_list:   "open-day"
        }
      }
    end

    assert_redirected_to edit_node_path(node)
    assert_equal 'Event was successfully created.', flash[:notice]
  end

  test "should not create an event without a title or a node_id" do
    login_as :quentin

    assert_no_difference('Event.count') do
      post :create, params: { event: { start_time: Time.now, end_time: Time.now + 1.hour } }
    end

    assert_response :success # re-renders :new, not a redirect
  end

  test "should honour return_to on create" do
    login_as :quentin
    node = create_node_with_published_page

    post :create, params: {
      event:     { node_id: node.id, start_time: Time.now, end_time: Time.now + 1.hour },
      return_to: node_path(node)
    }

    assert_redirected_to node_path(node)
  end

  test "should update event" do
    login_as :quentin
    node  = create_node_with_published_page
    event = Event.create!(node_id: node.id, start_time: Time.now, end_time: Time.now + 1.hour)

    put :update, params: { id: event.id, event: { title: "Updated title" } }

    assert_redirected_to events_path
    assert_equal "Updated title", event.reload.title
  end

  test "should destroy event" do
    login_as :quentin
    node  = create_node_with_published_page
    event = Event.create!(node_id: node.id, start_time: Time.now, end_time: Time.now + 1.hour)

    assert_difference('Event.count', -1) do
      delete :destroy, params: { id: event.id }
    end

    assert_redirected_to events_url
  end
end

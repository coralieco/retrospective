# frozen_string_literal: true

require 'test_helper'

class Retrospective::ActionsStepTest < ActionDispatch::IntegrationTest
  test 'ensure votes are closed' do
    retrospective = create(:retrospective, step: 'actions')
    reflection = create(:reflection, :glad, owner: retrospective.organizer)
    retrospective.update!(discussed_reflection: reflection)
    logged_in_as(retrospective.organizer)
    visit retrospective_path(retrospective)

    within ".reflection[data-id='#{reflection.id}'] .vote-corner" do
      refute_css '.vote'
      refute_css '.unvote'
    end
  end

  test 'initial discussed reflection is the one with most votes' do
    retrospective = create(:retrospective, step: 'voting')
    other_participant = create(:other_participant, retrospective: retrospective)
    reflection_a = create(:reflection, :glad, owner: retrospective.organizer)
    reflection_b = create(:reflection, :sad, owner: other_participant)
    create_list(:vote, 3, target: reflection_a, author: retrospective.organizer)
    create_list(:vote, 2, target: reflection_b, author: other_participant)

    logged_in_as(retrospective.organizer)
    visit retrospective_path(retrospective)

    click_on 'Next'
    within '#discussed-reflection .reflection' do
      assert_text 'A glad reflection'
    end

    other_participant_window = open_new_window
    within_window(other_participant_window) do
      logged_in_as(other_participant)
      visit retrospective_path(retrospective)

      within '#discussed-reflection .reflection' do
        assert_text 'A glad reflection'
      end
    end
  end

  test 'organizer can change the discussed reflection' do
    retrospective = create(:retrospective, step: 'actions')
    other_participant = create(:other_participant, retrospective: retrospective)
    reflection_a = create(:reflection, :glad, owner: retrospective.organizer)
    create(:reflection, :sad, owner: other_participant)
    create(:vote, target: reflection_a, author: retrospective.organizer)
    retrospective.update!(discussed_reflection: reflection_a)

    logged_in_as(retrospective.organizer)
    visit retrospective_path(retrospective)

    within '.reflection' do
      assert_text 'A glad reflection'
    end

    all('#reflections-list .sticky-bookmark').last.click

    within '.reflection' do
      assert_text 'A sad reflection'
    end

    other_participant_window = open_new_window
    within_window(other_participant_window) do
      logged_in_as(other_participant)
      visit retrospective_path(retrospective)

      within '.reflection' do
        assert_text 'A sad reflection'
      end

      all('#reflections-list .sticky-bookmark').first.click

      within '.reflection' do
        assert_text 'A sad reflection'
      end
    end
  end

  test 'changing the discussed reflection to a topic selects the first reflection from this topic' do
    retrospective = create(:retrospective, step: 'actions')
    reflection_a = create(:reflection, :glad, owner: retrospective.organizer, content: 'Most upvoted reflection')
    reflection_b = create(:reflection, :glad, owner: retrospective.organizer, content: 'First reflection')
    reflection_c = create(:reflection, :glad, owner: retrospective.organizer, content: 'Second reflection')
    topic = create(:topic, retrospective: retrospective, reflections: [reflection_b, reflection_c])
    create_list(:vote, 2, target: reflection_a, author: retrospective.organizer)
    create(:vote, target: topic, author: retrospective.organizer)
    retrospective.update!(discussed_reflection: reflection_a)

    logged_in_as(retrospective.organizer)
    visit retrospective_path(retrospective)

    within '.reflection' do
      assert_text 'Most upvoted reflection'
    end

    assert_equal 4, all('#reflections-list .sticky-bookmark').count
    topic_sticky_bookmark = all('#reflections-list .sticky-bookmark')[1]
    within topic_sticky_bookmark do
      assert_text 'reflection'
    end

    topic_sticky_bookmark.hover
    topic_sticky_bookmark.click
    within '.reflection' do
      assert_text 'First reflection'
    end
  end

  test 'can create a task' do
    retrospective = create(:retrospective, step: 'actions')
    other_participant = create(:other_participant, retrospective: retrospective)
    reflection = create(:reflection, :glad, owner: retrospective.organizer)
    retrospective.update!(discussed_reflection: reflection)

    logged_in_as(retrospective.organizer)
    visit retrospective_path(retrospective)

    fill_in 'content', with: 'my task'
    select retrospective.organizer.surname, from: 'assignee'
    click_on 'Take action'

    within '#tasks-list' do
      assert_text 'Assigned to Organizer'
      assert_text 'my task'
    end

    other_participant_window = open_new_window
    within_window(other_participant_window) do
      logged_in_as(other_participant)
      visit retrospective_path(retrospective)

      within '#tasks-list' do
        assert_text 'Assigned to Organizer'
        assert_text 'my task'
      end
    end
  end

  test 'can create a task even when the discussed reflection changed' do
    retrospective = create(:retrospective, step: 'actions')
    reflection_a = create(:reflection, :glad, owner: retrospective.organizer)
    create(:reflection, :sad, owner: retrospective.organizer)
    retrospective.update!(discussed_reflection: reflection_a)

    logged_in_as(retrospective.organizer)
    visit retrospective_path(retrospective)

    fill_in 'content', with: 'my task'
    select retrospective.organizer.surname, from: 'assignee'

    all('#reflections-list .sticky-bookmark').last.click

    within '#action-editor' do
      assert_text 'You are writing an action for a reflection that is not the one currently displayed'
      assert_text '(A glad reflection)'
    end

    click_on 'Take action'

    within '#tasks-list', visible: false do
      refute_text 'Assigned to Organizer'
      refute_text 'my task'
    end

    all('#reflections-list .sticky-bookmark').first.click

    within '#tasks-list' do
      assert_text 'Assigned to Organizer'
      assert_text 'my task'
    end
  end

  test 'can start to write a task and change to the currently discussed reflection' do
    retrospective = create(:retrospective, step: 'actions')
    reflection_a = create(:reflection, :glad, owner: retrospective.organizer)
    create(:reflection, :sad, owner: retrospective.organizer)
    retrospective.update!(discussed_reflection: reflection_a)

    logged_in_as(retrospective.organizer)
    visit retrospective_path(retrospective)

    fill_in 'content', with: 'my task'
    select retrospective.organizer.surname, from: 'assignee'

    all('#reflections-list .sticky-bookmark').last.click

    within '#action-editor' do
      assert_text 'You are writing an action for a reflection that is not the one currently displayed'
      assert_text '(A glad reflection)'
      click_on 'Change to currently displayed reflection'
    end

    within '#action-editor', visible: false do
      refute_text 'You are writing an action for a reflection that is not the one currently displayed'
    end

    click_on 'Take action'

    within '#tasks-list' do
      assert_text 'Assigned to Organizer'
      assert_text 'my task'
    end
  end

  test 'can update a task' do
    retrospective = create(:retrospective, step: 'actions')
    other_participant = create(:other_participant, retrospective: retrospective)
    reflection = create(:reflection, :glad, owner: retrospective.organizer)
    retrospective.update!(discussed_reflection: reflection)

    logged_in_as(retrospective.organizer)
    visit retrospective_path(retrospective)

    fill_in 'content', with: 'my task'
    select retrospective.organizer.surname, from: 'assignee'
    click_on 'Take action'

    within '#tasks-list' do
      assert_text 'Assigned to Organizer'
      assert_text 'my task'
      find('.edit-icon').click
    end

    within '#action-editor' do
      assert_text 'You are editing an action for the following reflection:'
      assert_text 'A glad reflection'
      fill_in 'content', with: 'my updated task'
    end
    select other_participant.surname, from: 'assignee'
    within '#action-editor' do
      click_on 'Update'
    end

    within '#tasks-list' do
      assert_text 'Assigned to Other participant'
      assert_text 'my updated task'
    end
  end

  test 'can delete a task' do
    retrospective = create(:retrospective, step: 'actions')
    organizer = retrospective.organizer
    reflection = create(:reflection, :glad, owner: retrospective.organizer)
    retrospective.update!(discussed_reflection: reflection)
    reflection.tasks.create!(author: organizer, assignee: organizer, description: 'my task')

    logged_in_as(organizer)
    visit retrospective_path(retrospective)

    within '#tasks-list' do
      assert_text 'Assigned to Organizer'
      assert_text 'my task'

      dismiss_confirm do
        find('.delete-icon').click
      end
      assert_text 'Assigned to Organizer'
      assert_text 'my task'

      accept_confirm do
        find('.delete-icon').click
      end
      refute_text 'Assigned to Organizer'
      refute_text 'my task'
    end
  end
end

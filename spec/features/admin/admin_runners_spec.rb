require 'spec_helper'

describe "Admin Runners" do
  include StubENV

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    sign_in(create(:admin))
  end

  describe "Runners page" do
    let(:pipeline) { create(:ci_pipeline) }

    context "when there are runners" do
      it 'has all necessary texts' do
        runner = FactoryBot.create(:ci_runner, contacted_at: Time.now)
        FactoryBot.create(:ci_build, pipeline: pipeline, runner_id: runner.id)
        visit admin_runners_path

        expect(page).to have_text "Setup a shared Runner manually"
        expect(page).to have_text "Runners currently online: 1"
      end

      describe 'search' do
        before do
          FactoryBot.create :ci_runner, description: 'runner-foo'
          FactoryBot.create :ci_runner, description: 'runner-bar'

          visit admin_runners_path
        end

        it 'shows correct runner when description matches' do
          within '#runners-search' do
            fill_in 'search', with: 'runner-foo'
            click_button 'Search'
          end

          expect(page).to have_content("runner-foo")
          expect(page).not_to have_content("runner-bar")
        end

        it 'shows no runner when description does not match' do
          within '#runners-search' do
            fill_in 'search', with: 'runner-baz'
            click_button 'Search'
          end

          expect(page).to have_text 'No runners found'
        end
      end

      describe 'filter by status', :js do
        it 'shows correct runner when status matches' do
          FactoryBot.create :ci_runner, description: 'runner-active', active: true
          FactoryBot.create :ci_runner, description: 'runner-paused', active: false

          visit admin_runners_path

          expect(page).to have_content 'runner-active'
          expect(page).to have_content 'runner-paused'

          click_button 'Status'
          click_link 'Active'
          expect(page).to have_content 'runner-active'
          expect(page).not_to have_content 'runner-paused'
        end

        it 'shows no runner when status does not match' do
          FactoryBot.create :ci_runner, :online, description: 'runner-active', active: true
          FactoryBot.create :ci_runner, :online, description: 'runner-paused', active: false

          visit admin_runners_path

          click_button 'Status'
          click_link 'Offline'

          expect(page).not_to have_content 'runner-active'
          expect(page).not_to have_content 'runner-paused'

          expect(page).to have_text 'No runners found'
        end
      end

      describe 'filter by status and enter search term', :js do
        before do
          FactoryBot.create :ci_runner, description: 'runner-a-1', active: true
          FactoryBot.create :ci_runner, description: 'runner-a-2', active: false
          FactoryBot.create :ci_runner, description: 'runner-b-1', active: true

          visit admin_runners_path
        end

        it 'shows correct runner when status is selected first and then search term is entered' do
          click_button 'Status'
          click_link 'Active'
          expect(page).to have_content 'runner-a-1'
          expect(page).to have_content 'runner-b-1'
          expect(page).not_to have_content 'runner-a-2'

          within '#runners-search' do
            fill_in 'search', with: 'runner-a'
            click_button 'Search'
          end

          expect(page).to have_content 'runner-a-1'
          expect(page).not_to have_content 'runner-b-1'
          expect(page).not_to have_content 'runner-a-2'
        end

        it 'shows correct runner when search term is entered first and then status is selected' do
          within '#runners-search' do
            fill_in 'search', with: 'runner-a'
            click_button 'Search'
          end

          expect(page).to have_content 'runner-a-1'
          expect(page).to have_content 'runner-a-2'
          expect(page).not_to have_content 'runner-b-1'

          click_button 'Status'
          click_link 'Active'
          expect(page).to have_content 'runner-a-1'
          expect(page).not_to have_content 'runner-b-1'
          expect(page).not_to have_content 'runner-a-2'
        end
      end
    end

    context "when there are no runners" do
      before do
        visit admin_runners_path
      end

      it 'has all necessary texts including no runner message' do
        expect(page).to have_text "Setup a shared Runner manually"
        expect(page).to have_text "Runners currently online: 0"
        expect(page).to have_text 'No runners found'
      end
    end

    context 'group runner' do
      let(:group) { create(:group) }
      let!(:runner) { create(:ci_runner, :group, groups: [group]) }

      it 'shows the label and does not show the project count' do
        visit admin_runners_path

        within "#runner_#{runner.id}" do
          expect(page).to have_selector '.badge', text: 'group'
          expect(page).to have_text 'n/a'
        end
      end
    end

    context 'shared runner' do
      it 'shows the label and does not show the project count' do
        runner = create :ci_runner, :instance

        visit admin_runners_path

        within "#runner_#{runner.id}" do
          expect(page).to have_selector '.badge', text: 'shared'
          expect(page).to have_text 'n/a'
        end
      end
    end

    context 'specific runner' do
      it 'shows the label and the project count' do
        project = create :project
        runner = create :ci_runner, :project, projects: [project]

        visit admin_runners_path

        within "#runner_#{runner.id}" do
          expect(page).to have_selector '.badge', text: 'specific'
          expect(page).to have_text '1'
        end
      end
    end
  end

  describe "Runner show page" do
    let(:runner) { FactoryBot.create :ci_runner }

    before do
      @project1 = FactoryBot.create(:project)
      @project2 = FactoryBot.create(:project)
      visit admin_runner_path(runner)
    end

    describe 'runner info' do
      it { expect(find_field('runner_token').value).to eq runner.token }
    end

    describe 'projects' do
      it 'contains project names' do
        expect(page).to have_content(@project1.full_name)
        expect(page).to have_content(@project2.full_name)
      end
    end

    describe 'search' do
      before do
        search_form = find('#runner-projects-search')
        search_form.fill_in 'search', with: @project1.name
        search_form.click_button 'Search'
      end

      it 'contains name of correct project' do
        expect(page).to have_content(@project1.full_name)
        expect(page).not_to have_content(@project2.full_name)
      end
    end

    describe 'enable/create' do
      shared_examples 'assignable runner' do
        it 'enables a runner for a project' do
          within '.unassigned-projects' do
            click_on 'Enable'
          end

          assigned_project = page.find('.assigned-projects')

          expect(assigned_project).to have_content(@project2.path)
        end
      end

      context 'with specific runner' do
        let(:runner) { create(:ci_runner, :project, projects: [@project1]) }

        before do
          visit admin_runner_path(runner)
        end

        it_behaves_like 'assignable runner'
      end

      context 'with locked runner' do
        let(:runner) { create(:ci_runner, :project, projects: [@project1], locked: true) }

        before do
          visit admin_runner_path(runner)
        end

        it_behaves_like 'assignable runner'
      end

      context 'with shared runner' do
        let(:runner) { create(:ci_runner, :instance) }

        before do
          @project1.destroy
          visit admin_runner_path(runner)
        end

        it_behaves_like 'assignable runner'
      end
    end

    describe 'disable/destroy' do
      let(:runner) { create(:ci_runner, :project, projects: [@project1]) }

      before do
        visit admin_runner_path(runner)
      end

      it 'enables specific runner for project' do
        within '.assigned-projects' do
          click_on 'Disable'
        end

        new_runner_project = page.find('.unassigned-projects')

        expect(new_runner_project).to have_content(@project1.path)
      end
    end
  end

  describe 'runners registration token' do
    let!(:token) { Gitlab::CurrentSettings.runners_registration_token }

    before do
      visit admin_runners_path
    end

    it 'has a registration token' do
      expect(page.find('#registration_token')).to have_content(token)
    end

    describe 'reload registration token' do
      let(:page_token) { find('#registration_token').text }

      before do
        click_button 'Reset runners registration token'
      end

      it 'changes registration token' do
        expect(page_token).not_to eq token
      end
    end
  end
end

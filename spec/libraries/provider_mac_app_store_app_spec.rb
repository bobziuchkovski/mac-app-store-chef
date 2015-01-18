# Encoding: UTF-8

require 'ax_elements'
require_relative '../spec_helper'
require_relative '../../libraries/provider_mac_app_store_app'

describe Chef::Provider::MacAppStoreApp do
  let(:platform) { { platform: 'mac_os_x', version: '10.9.2' } }
  let(:node) { Fauxhai.mock(platform).data }
  let(:app_name) { 'Some App' }
  let(:app_id) { 'com.example.someapp' }
  let(:axe_gem) { double(run_action: true) }
  let(:system_wide) { double(focused_application: 'something') }
  let(:running_applications) { [] }
  let(:new_resource) do
    r = Chef::Resource::MacAppStoreApp.new(app_name, nil)
    r.app_id(app_id)
    r
  end
  let(:provider) { described_class.new(new_resource, nil) }

  before(:each) do
    allow_any_instance_of(described_class).to receive(:node).and_return(node)
      allow_any_instance_of(described_class).to receive(:axe_gem)
        .and_return(axe_gem)
      allow(AX::SystemWide).to receive(:new).and_return(system_wide)
      allow(NSRunningApplication)
        .to receive(:runningApplicationsWithBundleIdentifier)
        .with('com.apple.appstore').and_return(running_applications)
  end

  describe 'AXE_VERSION' do
    it 'pins AXE to 6.x' do
      expect(Chef::Provider::MacAppStoreApp::AXE_VERSION).to eq('~> 6.0')
    end
  end

  describe '#initialize' do
    shared_examples_for 'any initial state' do
      it 'installs the AXE gem' do
        expect(axe_gem).to receive(:run_action).with(:install)
        provider
      end

      it 'saves the original focused app for later' do
        expect(provider.original_focus).to eq('something')
      end
    end

    context 'App Store not running' do
      let(:running_applications) { [] }

      it_behaves_like 'any initial state'

      it 'will quit the App Store when done' do
        expect(provider.quit_when_done?).to eq(true)
      end
    end

    context 'App Store running' do
      let(:running_applications) { [true] }

      it_behaves_like 'any initial state'

      it 'will leave the App Store open when done' do
        expect(provider.quit_when_done?).to eq(false)
      end
    end
  end

  describe '#whyrun_supported?' do
    it 'returns true' do
      expect(provider.whyrun_supported?).to eq(true)
    end
  end

  describe '#load_current_resource' do
    let(:installed) { true }

    before(:each) do
      allow_any_instance_of(described_class).to receive(:installed?)
        .and_return(installed)
    end

    it 'returns a MacAppStoreApp resource instance' do
      expected = Chef::Resource::MacAppStoreApp
      expect(provider.load_current_resource).to be_an_instance_of(expected)
    end

    it 'sets the resource installed status' do
      expect(provider.load_current_resource.installed?).to eq(true)
    end
  end

  describe '#action_install' do
    [
      :press, :install_button, :quit_when_done?, :set_focus_to, :original_focus
    ].each do |i|
      let(i) { i }
    end
    let(:installed?) { false }
    let(:current_resource) { double(installed?: installed?) }
    let(:app_store) { double(terminate: true) }

    before(:each) do
      [
        :current_resource,
        :app_store,
        :press,
        :install_button,
        :quit_when_done?,
        :set_focus_to,
        :original_focus
      ].each do |r|
        allow_any_instance_of(described_class).to receive(r).and_return(send(r))
      end
    end

    shared_examples_for 'any installed state' do
      it 'sets installed state to true' do
        expect(new_resource).to receive(:'installed=').with(true)
        provider.action_install
      end
    end

    shared_examples_for 'quit when done' do
      it 'quits the App Store' do
        expect(app_store).to receive(:terminate)
        provider.action_install
      end
    end

    shared_examples_for 'do not quit when done' do
      it 'does not quit the App Store' do
        expect(app_store).not_to receive(:terminate)
        provider.action_install
      end
    end

    context 'not already installed' do
      let(:installed?) { false }

      it_behaves_like 'any installed state'

      it 'presses the install button' do
        expect_any_instance_of(described_class).to receive(:press)
          .with(install_button)
        provider.action_install
      end

      context 'App Store not already running' do
        let(:quit_when_done?) { true }

        it 'quits the App Store' do
          expect(app_store).to receive(:terminate)
          provider.action_install
        end
      end

      context 'App Store already running' do
        let(:quit_when_done?) { false }

        it 'does not quit the app store' do
          expect(app_store).not_to receive(:terminate)
          provider.action_install
        end
      end

      it 'sets focus back on the original app' do
        expect_any_instance_of(described_class).to receive(:set_focus_to)
          .with(original_focus)
        provider.action_install
      end
    end

    context 'already installed' do
      let(:installed?) { true }

      it 'does not do anything' do
        [:press, :sleep, :set_focus_to].each do |m|
          expect_any_instance_of(described_class).not_to receive(m)
        end
        provider.action_install
      end
    end
  end

  describe '#latest_version' do
    let(:version) { '1.2.3' }
    let(:app_page) do
      double(
        main_window: double(static_text: double(parent: double(
          static_text: double(value: version)))
        )
      )
    end

    before(:each) do
      allow_any_instance_of(described_class).to receive(:app_page)
        .and_return(app_page)
    end

    it 'returns the version number' do
      expect(provider.send(:latest_version)).to eq('1.2.3')
    end
  end

  describe '#installed?' do
    let(:installed) { nil }
    let(:shell_out) { double(error?: !installed) }

    before(:each) do
      allow_any_instance_of(described_class).to receive(:shell_out)
        .with("pkgutil --pkg-info #{app_id}").and_return(shell_out)
    end

    context 'app installed' do
      let(:installed) { true }

      it 'returns true' do
        expect(provider.send(:installed?)).to eq(true)
      end
    end

    context 'app not installed' do
      let(:installed) { false }

      it 'returns false' do
        expect(provider.send(:installed?)).to eq(false)
      end
    end
  end

  describe '#install_button' do
    let(:button) { 'i am a button' }
    let(:app_page) do
      double(main_window: double(web_area: double(group: double(group: double(
        button: button
      )))))
    end

    before(:each) do
      allow_any_instance_of(described_class).to receive(:app_page)
        .and_return(app_page)
    end

    it 'returns the install button' do
      expect(provider.send(:install_button)).to eq(button)
    end
  end

  describe '#app_page' do
    let(:press) { true }
    let(:row) { double(link: 'link') }
    let(:app_store) { 'the app store' }

    before(:each) do
      [:press, :row, :app_store].each do |m|
        allow_any_instance_of(described_class).to receive(m).and_return(send(m))
      end
    end

    it 'presses the app link' do
      expect_any_instance_of(described_class).to receive(:press).with('link')
      provider.send(:app_page)
    end

    it 'returns the app store object' do
      expect(provider.send(:app_page)).to eq(app_store)
    end
  end

  describe '#axe_gem' do
    it 'returns a chef_gem resource' do
      expected = Chef::Resource::ChefGem
      p = provider
      allow_any_instance_of(described_class).to receive(:axe_gem)
        .and_call_original
      expect(p.send(:axe_gem)).to be_an_instance_of(expected)
    end

    it 'uses AXE 6' do
      p = provider
      allow_any_instance_of(described_class).to receive(:axe_gem)
        .and_call_original
      expect(provider.send(:axe_gem).version).to eq('~> 6.0')
    end
  end
end

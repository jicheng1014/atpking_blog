require "application_system_test_case"

class ThoughtSubmissionTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.manage.window.resize_to(1400, 1000)
    visit new_session_path
    fill_in "email_address", with: users(:one).email_address
    fill_in "password", with: "password"
    click_button "登录"
    assert_selector "a", text: "管理"
  end

  test "all publishing entries block repeated clicks and shortcuts until the response arrives" do
    [root_path, thoughts_path, admin_thoughts_path].each do |path|
      visit path
      fill_in "thought_content", with: "只能发布一次 #{path}"
      hold_publication

      assert_difference "Thought.count", 1 do
        page.execute_script(<<~JS, path == root_path)
          const editor = document.querySelector('#thought_content');
          const form = editor.form;
          const button = form.querySelector('input[type=submit]');
          if (arguments[0]) form.requestSubmit(); else button.click();
          button.click();
          form.requestSubmit();
          editor.dispatchEvent(new KeyboardEvent('keydown', {key: 'Enter', ctrlKey: true, bubbles: true}));
          window.Stimulus.getControllerForElementAndIdentifier(form, 'paste-image').updateForm();
        JS
        assert_button "发布中…", disabled: true
        assert_equal 1, page.evaluate_script("window.publicationRequests")
        page.execute_script("window.releasePublication()")
        assert_text "灵感已发布"
      end
    end
  end

  test "network failures unlock publishing and preserve content for a retry" do
    visit root_path
    fill_in "thought_content", with: "失败后重试"
    hold_publication

    assert_no_difference "Thought.count" do
      click_button "发布"
      assert_button "发布中…", disabled: true
      page.execute_script("window.rejectPublication(new TypeError('Network failure'))")
      assert_button "发布", disabled: false
      assert_field "thought_content", with: "失败后重试"
    end

    page.execute_script("window.fetch = window.originalFetch")
    assert_difference "Thought.count", 1 do
      click_button "发布"
      assert_text "灵感已发布"
    end
  end

  private

  def hold_publication
    page.execute_script <<~JS
      window.originalFetch = window.fetch;
      window.publicationRequests = 0;
      window.fetch = (...args) => {
        if (new URL(args[0], location.href).pathname === '/admin/thoughts' && args[1]?.method.toUpperCase() === 'POST') {
          window.publicationRequests++;
          return new Promise((resolve, reject) => {
            window.releasePublication = () => window.originalFetch(...args).then(resolve, reject);
            window.rejectPublication = reject;
          });
        }
        return window.originalFetch(...args);
      };
    JS
  end
end

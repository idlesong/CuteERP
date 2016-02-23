require 'test_helper'

class UserFlowsTest < ActionDispatch::IntegrationTest
  # test "the truth" do
  #   assert true
  # end
  fixtures :users

  test "login and browse site" do
    # login via https
    https!
    get "/login"
    assert_response :success

    post_via_rediract "/login", :username => users(:idlesong).username, :password => users(:idlesong).password
    assert_equal '/admin', path
    assert_equal 'Welcome idlesong!', flash[:notice]
  end

end

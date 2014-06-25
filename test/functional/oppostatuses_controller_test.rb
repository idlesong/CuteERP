require 'test_helper'

class OppostatusesControllerTest < ActionController::TestCase
  setup do
    @oppostatus = oppostatuses(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:oppostatuses)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create oppostatus" do
    assert_difference('Oppostatus.count') do
      post :create, oppostatus: { issue: @oppostatus.issue, status: @oppostatus.status }
    end

    assert_redirected_to oppostatus_path(assigns(:oppostatus))
  end

  test "should show oppostatus" do
    get :show, id: @oppostatus
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @oppostatus
    assert_response :success
  end

  test "should update oppostatus" do
    put :update, id: @oppostatus, oppostatus: { issue: @oppostatus.issue, status: @oppostatus.status }
    assert_redirected_to oppostatus_path(assigns(:oppostatus))
  end

  test "should destroy oppostatus" do
    assert_difference('Oppostatus.count', -1) do
      delete :destroy, id: @oppostatus
    end

    assert_redirected_to oppostatuses_path
  end
end

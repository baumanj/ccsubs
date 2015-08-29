module ApplicationHelper
  FLASH_KEY_TO_BOOTSTRAP_CLASS = { 'success' => 'success', 
                                   'notice'  => 'info',
                                   'alert'   => 'warning',
                                   'error'   => 'danger' }
  def flash_class(key)
    FLASH_KEY_TO_BOOTSTRAP_CLASS[key]
  end

  def mailer
    UserMailer.active_user = current_user
    UserMailer
  end
end

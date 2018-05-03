defmodule EvercamMedia.EvercamBot.Commands do
  use EvercamMedia.EvercamBot.Router
  use EvercamMedia.EvercamBot.Commander

  Application.ensure_all_started :inets

  @doc """
    Logger module injected from App.Commander
  """
  command ["start"] do
    Logger.log :info, "Command /start"
    send_message "Wellcome, write anything to show the main menu"
  end

  callback_query_command "choose" do
    Logger.log :info, "Callback Query Command /choose"
    id = String.downcase(update.callback_query.from.username)
    user = User.by_telegram_username(id)
    cameras_list = Camera.for(user, true)

    case update.callback_query.data do

      "/choose live" ->
            Enum.each(cameras_list, fn(camera) ->
              {:ok, _} = send_message "#{camera.exid}",
                  reply_markup: %Model.InlineKeyboardMarkup{
                    inline_keyboard: [
                      [
                        %{
                          callback_data: "/choose mycamera",
                          text: "\xF0\x9F\x93\xB9 #{camera.name}"
                        },
                      ],
                    ]
                  }
            end)

      "/choose all" ->
        Enum.each(cameras_list, fn(camera) ->
          camera_exid = "#{camera.exid}"
          {200, reponse} = EvercamMediaWeb.SnapshotController.snapshot_with_user(camera_exid, user, false)
          File.write!("image.png", reponse[:image])
          send_photo("image.png")
        end)

      "/choose mycamera" ->
        camera_exid = "#{update.callback_query.message.text}"
        {200, reponse} = EvercamMediaWeb.SnapshotController.snapshot_with_user(camera_exid, user, false)
        File.write!("image.png", reponse[:image])
        send_photo("image.png")

      "/choose comparison" ->
        Enum.each(cameras_list, fn(camera) ->
          send_message "#{camera.id}.#{camera.exid}",
              reply_markup: %Model.InlineKeyboardMarkup{
                inline_keyboard: [
                  [
                    %{
                      callback_data: "/choose mycomparison",
                      text: "\xF0\x9F\x93\xB9 #{camera.name}"
                    },
                  ],
                ]
              }
        end)

        "/choose clip" ->
          Enum.each(cameras_list, fn(camera) ->
            send_message "#{camera.id}.#{camera.exid}",
                reply_markup: %Model.InlineKeyboardMarkup{
                  inline_keyboard: [
                    [
                      %{
                        callback_data: "/choose myclip",
                        text: "\xF0\x9F\x93\xB9 #{camera.name}"
                      },
                    ],
                  ]
                }
          end)

      "/choose mycomparison" ->
        text = String.split("#{update.callback_query.message.text}", ".")
        id = Enum.at(text, 0)
        camera_exid = Enum.at(text, 1)
        compare = Compare.get_by_camera(id)
        last_compare = List.last(compare)
        video = EvercamMedia.TimelapseRecording.S3.do_load("#{camera_exid}/compares/#{last_compare.id}/#{last_compare.id}.gif")
        File.write!("compare.gif", video)
        send_video("compare.gif")

      "/choose myclip" ->
        text = String.split("#{update.callback_query.message.text}", ".")
        id = Enum.at(text, 0)
        camera_exid = Enum.at(text, 1)
        archive = Archive.by_camera_id(id)
        last_archive = List.last(archive)
        video = EvercamMedia.TimelapseRecording.S3.do_load("#{camera_exid}/archives/#{last_archive.id}/#{last_archive.id}.gif")
        File.write!("clip.gif", video)
        send_video("clip.gif")
      end
  end

  @doc """
    The `message` macro must come at the end since it matches anything.
    You may use it as a fallback.
  """
  message do
      id = update.message.chat.username
      user = User.by_telegram_username(id)
      case user do
        nil ->
          send_message "Unregistered user"
        user ->
          {:ok, _} = send_message "what do you want to see?",
          reply_markup: %Model.InlineKeyboardMarkup{
            inline_keyboard: [
              [
                %{
                  callback_data: "/choose live",
                  text: "Live view",
                },
              ],
              [
              %{
                callback_data: "/choose all",
                text: "View all images",
              },
              ],
              [
                %{
                  callback_data: "/choose comparison",
                  text: "Last Comparison",
                },
              ],
              [
                %{
                  callback_data: "/choose clip",
                  text: "Last Clip",
                },
              ]
            ]
          }
      end
  end
end

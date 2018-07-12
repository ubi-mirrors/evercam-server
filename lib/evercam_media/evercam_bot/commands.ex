defmodule EvercamMedia.EvercamBot.Commands do
  use EvercamMedia.EvercamBot.Router
  use EvercamMedia.EvercamBot.Commander

  Application.ensure_all_started :inets

  @doc """
    Logger module injected from App.Commander
  """
  command ["start"] do
    Logger.log :info, "Command /start"
    send_message "Wellcome, write anything to show the main menu",
    reply_markup: %Model.ReplyKeyboardMarkup{
      keyboard: [
        [
          %{
            text: "Live view",
          },
        ],
        [
          %{
            text: "View all images",
          },
        ],
        [
          %{
            text: "Last comparison",
          },
        ],
        [
          %{
            text: "Last clip",
          },
        ]
      ]
    }
  end

  callback_query_command "choose" do
    Logger.log :info, "Callback Query Command /choose"
    id = String.downcase(update.callback_query.from.username)
    user = User.by_telegram_username(id)

    case update.callback_query.data do

      "/choose mycamera" ->
        camera_exid = "#{update.callback_query.message.text}"
        case EvercamMediaWeb.SnapshotController.snapshot_with_user(camera_exid, user, false) do
          {200, response} ->
            File.write!("image.png", response[:image])
            send_photo("image.png")
            File.rm!("image.png")
          {_, response} ->
            send_message "#{camera_exid}: #{response.message}"
        end

      "/choose mycomparison" ->
        text = String.split("#{update.callback_query.message.text}", ".")
        id = Enum.at(text, 0)
        camera_exid = Enum.at(text, 1)
        compare = Compare.get_last_by_camera(id)

        case EvercamMedia.TimelapseRecording.S3.do_load("#{camera_exid}/compares/#{compare.exid}/#{compare.exid}.mp4") do
          {:ok, response} ->
            File.write("compare.mp4", response)
            send_video("compare.mp4")
            File.rm!("compare.mp4")
          {:error, response} ->
            send_message "#{camera_exid}: #{response.message}"
        end

      "/choose myclip" ->
        text = String.split("#{update.callback_query.message.text}", ".")
        id = Enum.at(text, 0)
        camera_exid = Enum.at(text, 1)
        archive = Archive.get_last_by_camera(id)

        case EvercamMedia.TimelapseRecording.S3.do_load("#{camera_exid}/clips/#{archive.exid}/#{archive.exid}.mp4") do
          {:ok, response} ->
            File.write("clip.mp4", response)
            send_video("clip.mp4")
            File.rm!("clip.mp4")
          {:error, response} ->
            send_message "#{camera_exid}: #{response.message}"
        end
      end
  end

  @doc """
    The `message` macro must come at the end since it matches anything.
    You may use it as a fallback.
  """
  message do
    id = update.message.chat.username
    user = User.by_telegram_username(id)
    cameras_list = Camera.for(user, true)
    case user do
      nil ->
        send_message "Unregistered user"
      _user ->
        case update.message.text do
          "Live view" ->
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

          "View all images" ->
            Enum.each(cameras_list, fn(camera) ->
              camera_exid = "#{camera.exid}"
              case EvercamMediaWeb.SnapshotController.snapshot_with_user(camera_exid, user, false) do
                {200, response} ->
                  File.write!("image.png", response[:image])
                  send_photo("image.png")
                  File.rm!("image.png")
                {_, response} ->
                  send_message "#{camera_exid}: #{response.message}"
              end
            end)

          "Last comparison" ->
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

            "Last clip" ->
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

              _ ->
                send_message "Command not found"
                Logger.log :info, "Command not found"
        end
    end
  end
end

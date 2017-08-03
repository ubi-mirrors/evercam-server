defmodule EvercamMediaWeb.VendorModelView do
  use EvercamMedia.Web, :view

  def render("index.json", %{vendor_models: vendor_models, pages: pages, records: records}) do
    %{models: render_many(vendor_models, __MODULE__, "vendor_model.json"), pages: pages, records: records}
  end

  def render("show.json", %{vendor_model: vendor_model}) do
    %{models: render_many([vendor_model], __MODULE__, "vendor_model.json")}
  end

  def render("vendor_model.json", %{vendor_model: vendor_model}) do
    %{
      id: vendor_model.exid,
      name: vendor_model.name,
      vendor_id: vendor_model.vendor.exid,
      username: vendor_model.username,
      password: vendor_model.password,
      jpg_url: vendor_model.jpg_url,
      h264_url: vendor_model.h264_url,
      mjpg_url: vendor_model.mjpg_url,
      shape: vendor_model.shape,
      resolution: vendor_model.resolution,
      official_url: vendor_model.official_url,
      more_info: vendor_model.more_info,
      audio_url: vendor_model.audio_url,
      poe: vendor_model.poe,
      wifi: vendor_model.wifi,
      upnp: vendor_model.upnp,
      ptz: vendor_model.ptz,
      infrared: vendor_model.infrared,
      varifocal: vendor_model.varifocal,
      sd_card: vendor_model.sd_card,
      audio_io: vendor_model.audio_io,
      discontinued: vendor_model.discontinued,
      onvif: vendor_model.onvif,
      psia: vendor_model.psia,
      defaults: %{
        snapshots: %{
          h264: VendorModel.get_url(vendor_model, "h264"),
          lowres: VendorModel.get_url(vendor_model, "lowres"),
          jpg: VendorModel.get_url(vendor_model),
          mjpg: VendorModel.get_url(vendor_model, "mjpg"),
          mpeg4: VendorModel.get_url(vendor_model, "mpeg4"),
          mobile: VendorModel.get_url(vendor_model, "mobile")
        },
        auth: %{
          basic: %{
            username: vendor_model.config["auth"]["basic"]["username"],
            password: vendor_model.config["auth"]["basic"]["password"]
          }
        }
      },
      images: %{
        icon: VendorModel.get_image_url(vendor_model, "icon"),
        thumbnail: VendorModel.get_image_url(vendor_model, "thumbnail"),
        original: VendorModel.get_image_url(vendor_model)
      }
    }
  end
end

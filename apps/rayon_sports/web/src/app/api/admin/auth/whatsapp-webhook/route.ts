import { NextRequest, NextResponse } from "next/server";
import { getAdminSupabase } from "@/lib/supabase/admin";

export const dynamic = "force-dynamic";

// This webhook should be configured in Supabase under Authentication -> Providers -> SMS -> Custom SMS Provider
// It receives the payload: { user: { phone: "+250788767816" }, sms: { otp: "123456" } }
export async function POST(request: NextRequest) {
  try {
    const payload = await request.json();
    
    if (!payload?.user?.phone || !payload?.sms?.otp) {
      return NextResponse.json({ error: "Invalid webhook payload" }, { status: 400 });
    }

    const { phone, id } = payload.user;
    const { otp } = payload.sms;

    // Verify if we actually want to allow this user (double-check via DB if needed)
    const adminClient = getAdminSupabase();
    if (adminClient) {
      const { data: adminAccess } = await adminClient
        .from("admin_phone_access")
        .select("user_id")
        .eq("user_id", id)
        .maybeSingle();
      
      // Additional safety check
      if (!adminAccess) {
        console.warn(`Attempted OTP send to unauthorized phone: ${phone}`);
        return NextResponse.json({ error: "Unauthorized" }, { status: 403 });
      }
    }

    // Call Meta WhatsApp Cloud API
    const whatsappToken = process.env.WHATSAPP_CLOUD_API_TOKEN;
    const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;

    if (!whatsappToken || !phoneNumberId) {
      console.warn("WhatsApp Cloud API credentials not configured. OTP was: ", otp);
      // Return 200 anyway so Supabase doesn't fail the auth flow in dev environments
      return NextResponse.json({ success: true, warning: "Credentials missing, logged to console" });
    }

    // Send WhatsApp Message using a pre-approved template for OTP
    const response = await fetch(
      `https://graph.facebook.com/v20.0/${phoneNumberId}/messages`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${whatsappToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to: phone.replace("+", ""),
          type: "template",
          template: {
            name: "admin_login_otp",
            language: {
              code: "en",
            },
            components: [
              {
                type: "body",
                parameters: [
                  {
                    type: "text",
                    text: otp,
                  },
                ],
              },
              {
                type: "button",
                sub_type: "url",
                index: "0",
                parameters: [
                  {
                    type: "text",
                    text: otp,
                  },
                ],
              },
            ],
          },
        }),
      }
    );

    const result = await response.json();

    if (!response.ok) {
      console.error("WhatsApp API error:", result);
      return NextResponse.json({ error: "Failed to send WhatsApp message" }, { status: 500 });
    }

    return NextResponse.json({ success: true, messageId: result?.messages?.[0]?.id });
  } catch (error) {
    console.error("WhatsApp Webhook error:", error);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}

import { NextRequest, NextResponse } from "next/server";

// ---------------------------------------------------------------------------
// Email service integration — TODO: wire up before launch
//
// Recommended: Resend (https://resend.com) — works perfectly on Vercel.
//
// Steps:
//   1. npm install resend
//   2. Add RESEND_API_KEY to Vercel environment variables
//   3. Create an audience in Resend dashboard, copy the audience ID
//   4. Add RESEND_AUDIENCE_ID to Vercel environment variables
//   5. Uncomment the Resend block below and delete the stub block
// ---------------------------------------------------------------------------

// import { Resend } from "resend";
// const resend = new Resend(process.env.RESEND_API_KEY);

export async function POST(req: NextRequest) {
  try {
    const { email } = await req.json();

    if (!email || typeof email !== "string") {
      return NextResponse.json({ error: "Valid email required" }, { status: 400 });
    }

    const normalized = email.trim().toLowerCase();

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)) {
      return NextResponse.json({ error: "Invalid email address" }, { status: 400 });
    }

    // ------------------------------------------------------------------
    // STUB — replace with Resend call once env vars are configured:
    //
    // await resend.contacts.create({
    //   email: normalized,
    //   audienceId: process.env.RESEND_AUDIENCE_ID!,
    // });
    // ------------------------------------------------------------------

    console.log(`[waitlist] new signup: ${normalized}`);

    return NextResponse.json({ success: true });
  } catch (err) {
    console.error("[waitlist] error:", err);
    return NextResponse.json(
      { error: "Something went wrong. Please try again." },
      { status: 500 }
    );
  }
}

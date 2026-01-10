import React from "react";

type ClassValue = string | false | null | undefined;

type DownloadItem = {
  href: string;
  os: string;
  file: string;
  borderColor: string;
  icon: React.ReactNode;
};

type ScreenshotItem = {
  src: string;
  label: string;
  description: string;
  aspect: string;
};

const downloads = {
  android: "https://github.com/axichat/axichat/releases/latest/download/app-production-release.apk",
  windows: "https://github.com/axichat/axichat/releases/latest/download/axichat-windows.zip",
  linux: "https://github.com/axichat/axichat/releases/latest/download/axichat-linux.tar.gz",
};

const heroHeadline = "Goodbye, Email";
const heroSubhead = "The best of instant messaging, email, and calendar all in one.";
const heroNote = "Verify checksums and signatures in GitHub release notes.";

const sectionLabels = {
  screenshots: "Screenshots",
  features: "Features",
  faq: "FAQ",
  about: "About",
  contact: "Contact",
};

const screenshots: { desktop: ScreenshotItem[]; mobile: ScreenshotItem[] } = {
  desktop: [
    {
      src: "/images/screenshots/desktop/axichat_desktop1.png",
      label: "Desktop — unified inbox",
      description: "Chat and mail together with keyboard-first navigation.",
      aspect: "aspect-[16/9]",
    },
    {
      src: "/images/screenshots/desktop/axichat_desktop_calendar.png",
      label: "Desktop — calendar + tasks",
      description: "Drag, drop, and schedule across weeks without leaving flow.",
      aspect: "aspect-[16/9]",
    },
    {
      src: "/images/screenshots/desktop/axichat_desktop2.png",
      label: "Desktop — focus view",
      description: "Stay on top of threads without switching apps.",
      aspect: "aspect-[16/9]",
    },
  ],
  mobile: [
    {
      src: "/images/screenshots/mobile/axichat_mobile_email.png",
      label: "Mobile — mail",
      description: "A chat-first view for email on the go.",
      aspect: "aspect-[9/16]",
    },
    {
      src: "/images/screenshots/mobile/axichat_mobile_muc.png",
      label: "Mobile — group chat",
      description: "XMPP group chat with privacy-first defaults.",
      aspect: "aspect-[9/16]",
    },
    {
      src: "/images/screenshots/mobile/axichat_mobile_calendar.png",
      label: "Mobile — calendar",
      description: "Plan the day with a thumb-friendly calendar UI.",
      aspect: "aspect-[9/16]",
    },
    {
      src: "/images/screenshots/mobile/axichat_mobile_calendar_alt.png",
      label: "Mobile — agenda",
      description: "Quickly scan tasks and commitments.",
      aspect: "aspect-[9/16]",
    },
  ],
};

const featureCards = [
  { emoji: "🌓", body: "Dark and light modes with brand color schemes" },
  { emoji: "🧭", body: "Unified inbox for chat + email side by side" },
  { emoji: "👥", body: "Group chats and per-conversation settings" },
  { emoji: "🔁", body: "Quick quote-reply" },
  { emoji: "😀", body: "Emoji reactions" },
  { emoji: "✅", body: "Delivery and read receipts with typing indicators" },
  { emoji: "🔄", body: "Stream management with automatic reconnect to stop messages dropping" },
  { emoji: "🧑‍🎨", body: "Upload your own avatar or use one of our cool defaults" },
  { emoji: "📌", body: "Message drafts, starred items, and pinned messages" },
  { emoji: "📎", body: "Rich attachments and inline previews" },
  { emoji: "🔍", body: "Fast search across chats, mail, and calendar" },
  { emoji: "🗂️", body: "Collaborative calendars with per-event permissions and owner/assignee roles" },
  { emoji: "🕒", body: "Availability sharing that shows overlaps before you schedule" },
  { emoji: "🤝", body: "Live calendar co-editing with comments, mentions, and RSVP updates" },
  { emoji: "🚀", body: "1st-party push notifications and offline sync" },
  { emoji: "📅", body: "Natural-language scheduling with drag+drop calendar editing" },
  { emoji: "➕", body: "One-tap add-to-calendar from simple text messages" },
  { emoji: "🗓️", body: "Tasks, reminders, and calendar in one view" },
  { emoji: "📤📥", body: "Calendar export/import for backups and migrations" },
  { emoji: "⚡", body: "Critical paths and agenda focus to surface what’s next" },
  { emoji: "🦾", body: "Accessibility-friendly modals and flows (keyboard/touch/reader aware)" },
  { emoji: "🌍", body: "Translated UI (English, Spanish, German, French, Chinese)" },
  { emoji: "🔄", body: "Sync across all your devices (Android, Linux, Windows)" },
  { emoji: "🖥️", body: "Desktop + mobile parity with keyboard shortcuts and touch affordances" },
  { emoji: "🔔", body: "Smart notifications (muting, per-chat overrides, do-not-disturb)" },
  { emoji: "🌐", body: "Works without Google/Firebase; pure XMPP + SMTP/IMAP core" },
];

const whyCards = [
  {
    title: "Tools matter",
    body: "Would you rather write a letter while standing up outside or sitting at your desk? Using the right software makes the same difference. Axichat is a digital desk for your online communication.",
  },
  {
    title: "Time matters",
    body: "You can always make more money, but not more time. Axichat’s calendar helps you seize the day, and the chat-like email format keeps you from retyping, opening the wrong emails, and spamming alt+tab.",
  },
  {
    title: "Collaboration matters",
    body: "Share availability, co-edit events, and resolve scheduling overlaps together so everyone stays aligned.",
  },
];

const faqItems = [
  {
    question: "What if I don't like Axichat?",
    answer: (
      <>
        <p>First, do no harm.</p>
        <p className="mt-3">
          You can easily export all your emails, chats and contacts out of Axichat and delete your account through
          the app.
        </p>
      </>
    ),
  },
  {
    question: "Can I connect my existing email accounts to Axichat?",
    answer: (
      <>
        <p>
          Yes, you can set up forwarding with your curent provider. They should have instructions on how to do so.
          Here are some quick links:{" "}
          <a
            href="https://support.google.com/mail/answer/10957?hl=en"
            target="_blank"
            rel="noreferrer"
            className="underline underline-offset-4"
          >
            Gmail
          </a>
          ,{" "}
          <a
            href="https://support.microsoft.com/en-us/office/forward-email-from-outlook-to-another-email-account-0d6d6b7b-3783-4e98-9c3e-1ea6e2e6b4d3"
            target="_blank"
            rel="noreferrer"
            className="underline underline-offset-4"
          >
            Outlook
          </a>
          .
        </p>
        <p className="mt-3">
          Note that Axichat does not yet support directly logging in to existing providers, so you cannot send email
          with an existing account. You can only receive it for now.
        </p>
      </>
    ),
  },
  {
    question: "Is it FOSS?",
    answer: (
      <p>
        Yes, Axichat is free and open source. Check out our{" "}
        <a href="https://github.com/axichat/axichat" target="_blank" rel="noreferrer" className="underline underline-offset-4">
          GitHub
        </a>{" "}
        and{" "}
        <a href="https://gitlab.com/axichat" target="_blank" rel="noreferrer" className="underline underline-offset-4">
          GitLab
        </a>
        .
      </p>
    ),
  },
  {
    question: "How does Axichat compare to Spike?",
    answer: (
      <>
        <p>
          Both Spike and Axichat are tremendous improvements over traditional email clients. However,
        </p>
        <ul className="mt-3 list-disc space-y-2 pl-5">
          <li>
            Spike still limits itself to the email protocol (SMTP). Axichat leverages both SMTP and XMPP, which is a
            protocol designed for instant messaging and enables us to provide a significantly richer IM experience,
            especially when you are talking to another Axichat user.
          </li>
          <li>
            Spike is closed source, so you have no idea what software you're actually using or what it's really doing
            behind the scenes. Axichat is open source, so you can see for yourself exactly what you're running and know
            that nothing suspicious is going on.
          </li>
          <li>
            Axichat is completely free to use with the only limit being server-side storage. Spike has free tiers, but
            charges for most of their plans.
          </li>
          <li>
            Axichat was made with Dart + Flutter and Spike was not. This allows us to implement a much more
            aesthetically pleasing interface with attention to detail and performance that can't be matched without
            Flutter.
          </li>
        </ul>
      </>
    ),
  },
];

const aboutCards = [
  {
    title: "What Axichat offers",
    items: [
      "Chat and email unified",
      "World-class calendar (no AI) + tasks",
      "On-device + in-transit encryption",
      "Native performance on every platform",
      "Offline functionality",
    ],
  },
  {
    title: "What we avoid",
    items: ["Trackers", "Vendor lock-in", "Sharing or selling data", "Centralized servers", "Proprietary dependencies"],
  },
];

const footerLinks = {
  sections: [
    { label: "Top", href: "#top" },
    { label: "Screenshots", href: "#screenshots" },
    { label: "Features", href: "#features" },
    { label: "FAQ", href: "#faq" },
    { label: "About", href: "#about" },
    { label: "Contact", href: "#contact" },
  ],
  legal: [
    { label: "Terms", href: "/axichat_terms.pdf" },
    { label: "Privacy", href: "/axichat_privacy.pdf" },
    { label: "License", href: "/LICENSE.txt" },
  ],
  links: [
    { label: "GitHub", href: "https://github.com/axichat/axichat" },
    { label: "Latest release", href: "https://github.com/axichat/axichat/releases/latest" },
  ],
};

const containerClassName = "mx-auto w-full max-w-6xl px-6";
const pngExtension = ".png";
const webpExtension = ".webp";
const brandIconPng = "/images/brand/axichat_icon.png";
const brandIconWebp = "/images/brand/axichat_icon.webp";

function cn(...classes: ClassValue[]) {
  return classes.filter(Boolean).join(" ");
}

function toWebpPath(path: string) {
  return path.endsWith(pngExtension) ? path.replace(pngExtension, webpExtension) : path;
}

function BrandIcon({ className, alt }: { className?: string; alt: string }) {
  return (
    <picture>
      <source srcSet={brandIconWebp} type="image/webp" />
      <img src={brandIconPng} alt={alt} className={className} />
    </picture>
  );
}

function AndroidIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden>
      <path
        d="M8.2 6.2 6.6 4.6M15.8 6.2l1.6-1.6"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
      />
      <path
        d="M7 9.2c0-2.8 2.2-5 5-5s5 2.2 5 5v7.2a2 2 0 0 1-2 2H9a2 2 0 0 1-2-2V9.2Z"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
      <path d="M9 11v.2M15 11v.2" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
      <path d="M6.5 10.5v5.5M17.5 10.5v5.5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
    </svg>
  );
}

function WindowsIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden>
      <path
        d="M3 5.5 10.5 4.4v7.1H3V5.5Zm0 13 7.5 1.1v-7.1H3v6Zm10.5-14.3L21 3v8.5h-7.5V4.2Zm0 15.6L21 21v-8.5h-7.5v7.3Z"
        fill="currentColor"
      />
    </svg>
  );
}

function TuxIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden>
      <path
        d="M12 3.2c-2.6 0-4.4 2.2-4.4 5 0 1.1.2 1.9.6 2.8-.5.7-1.2 1.9-1.2 3.6 0 3.2 2.2 6 5 6s5-2.8 5-6c0-1.7-.7-2.9-1.2-3.6.4-.9.6-1.7.6-2.8 0-2.8-1.8-5-4.4-5Z"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
      <path d="M10 9.6h.01M14 9.6h.01" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />
      <path
        d="M9.2 15.8c.8 1 1.7 1.5 2.8 1.5s2-.5 2.8-1.5"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
      />
      <path
        d="M8 18.5c-1.4 0-2.6-.9-3.2-2.3M16 18.5c1.4 0 2.6-.9 3.2-2.3"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
      />
    </svg>
  );
}

function ArrowRight({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden>
      <path d="M5 12h14" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      <path d="m13 5 7 7-7 7" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

function Container({ children }: { children: React.ReactNode }) {
  return <div className={containerClassName}>{children}</div>;
}

function SectionHeader({
  kicker,
  title,
  subtitle,
}: {
  kicker: string;
  title: string;
  subtitle?: React.ReactNode;
}) {
  return (
    <div className="mb-10">
      <div className="text-xs font-semibold uppercase tracking-[0.24em] text-white/60">{kicker}</div>
      <h2 className="mt-3 text-2xl font-semibold tracking-tight text-white sm:text-3xl font-display">{title}</h2>
      {subtitle ? <p className="mt-3 max-w-2xl text-sm leading-relaxed text-white/70">{subtitle}</p> : null}
    </div>
  );
}

function NavLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <a href={href} className="text-sm text-white/70 hover:text-white">
      {children}
    </a>
  );
}

function DownloadButton({ href, os, file, borderColor, icon }: DownloadItem) {
  return (
    <a
      href={href}
      className={cn(
        "group relative flex min-h-14 w-full min-w-[240px] items-center justify-between gap-4 rounded-2xl border bg-black/60 px-5",
        "backdrop-blur",
        "transition",
        "hover:bg-black/75",
        "focus:outline-none focus:ring-2 focus:ring-white/40"
      )}
      style={{ borderColor }}
    >
      <div className="flex items-center gap-3">
        <div className="grid h-9 w-9 place-items-center rounded-xl border border-white/10 bg-black">
          {icon}
        </div>
        <div className="leading-tight">
          <div className="text-sm font-semibold text-white whitespace-nowrap">Download {os}</div>
          <div className="text-xs text-white/60 whitespace-nowrap">{file}</div>
        </div>
      </div>
      <ArrowRight className="h-5 w-5 text-white/70 transition-transform group-hover:translate-x-0.5" />

      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-white/10" />
    </a>
  );
}

function FAQItem({
  question,
  answer,
  isOpen,
  onToggle,
}: {
  question: string;
  answer: React.ReactNode;
  isOpen: boolean;
  onToggle: () => void;
}) {
  return (
    <div className="rounded-2xl border border-white/10 bg-black/50">
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={isOpen}
        className="flex w-full items-center justify-between gap-4 px-5 py-4 text-left text-sm font-semibold text-white"
      >
        <span>{question}</span>
        <span className={cn("text-lg text-white/60 transition-transform", isOpen ? "rotate-45" : "rotate-0")}>+</span>
      </button>
      {isOpen ? <div className="px-5 pb-5 text-sm leading-relaxed text-white/70">{answer}</div> : null}
    </div>
  );
}

function ScreenshotCard({ src, label, description, aspect }: ScreenshotItem) {
  const webpSrc = toWebpPath(src);

  return (
    <figure className="rounded-3xl border border-white/10 bg-black/50 p-4 shadow-glow">
      <div className={cn("w-full overflow-hidden rounded-2xl border border-white/10 bg-black", aspect)}>
        <picture>
          <source srcSet={webpSrc} type="image/webp" />
          <img src={src} alt={label} className="h-full w-full object-cover" loading="lazy" />
        </picture>
      </div>
      <figcaption className="mt-3">
        <div className="text-sm text-white/80">{label}</div>
        <div className="mt-1 text-xs text-white/60">{description}</div>
      </figcaption>
    </figure>
  );
}

export default function App() {
  const [openFaqIndex, setOpenFaqIndex] = React.useState<number | null>(0);

  const downloadButtons: DownloadItem[] = [
    {
      href: downloads.android,
      os: "Android",
      file: ".apk",
      borderColor: "#3DDC84",
      icon: <AndroidIcon className="h-5 w-5 text-white" />,
    },
    {
      href: downloads.windows,
      os: "Windows",
      file: ".zip (Axichat.exe)",
      borderColor: "#0078D4",
      icon: <WindowsIcon className="h-5 w-5 text-white" />,
    },
    {
      href: downloads.linux,
      os: "Linux",
      file: ".tar.gz",
      borderColor: "#FFFFFF",
      icon: <TuxIcon className="h-5 w-5 text-white" />,
    },
  ];

  return (
    <div className="relative min-h-screen bg-black text-white font-body">
      <div className="pointer-events-none absolute inset-0 -z-10">
        <div className="absolute inset-0 surface-grid opacity-30" />
        <div className="absolute -left-32 top-32 h-72 w-72 rounded-full bg-white/10 blur-3xl animate-floatSlow" />
        <div className="absolute right-0 top-0 h-80 w-80 rounded-full bg-white/5 blur-3xl" />
      </div>

      <header className="sticky top-0 z-50 border-b border-white/10 bg-black/80 backdrop-blur">
        <Container>
          <div className="flex h-16 items-center justify-between">
            <a href="#top" className="flex items-center gap-3">
              <BrandIcon alt="Axichat" className="h-10 w-10" />
              <div className="text-lg font-display font-medium tracking-tight leading-none">Axichat</div>
            </a>

            <nav className="hidden items-center gap-6 md:flex">
              <NavLink href="#screenshots">{sectionLabels.screenshots}</NavLink>
              <NavLink href="#features">{sectionLabels.features}</NavLink>
              <NavLink href="#faq">{sectionLabels.faq}</NavLink>
              <NavLink href="#about">{sectionLabels.about}</NavLink>
              <NavLink href="#contact">{sectionLabels.contact}</NavLink>
            </nav>

            <div className="flex items-center gap-3">
              <a
                href="https://github.com/axichat/axichat"
                target="_blank"
                rel="noreferrer"
                className="hidden rounded-xl border border-white/15 bg-black px-4 py-2 text-sm text-white/80 hover:bg-white/5 md:inline-flex"
              >
                GitHub
              </a>
              <a
                href={downloads.android}
                className="rounded-xl border border-white/20 bg-white px-4 py-2 text-sm font-semibold text-black hover:bg-white/90"
              >
                Download
              </a>
            </div>
          </div>
        </Container>
      </header>

      <main id="top">
        <section className="border-b border-white/10 py-20 sm:py-28">
          <Container>
            <div className="mx-auto max-w-3xl text-center">
              <div className="mx-auto mb-6 flex w-fit items-center gap-3 rounded-full border border-white/15 bg-black/50 px-4 py-2 text-xs uppercase tracking-[0.3em] text-white/70">
                <span className="inline-flex h-2 w-2 rounded-full bg-white" />
                Chat + Email unified
              </div>
              <h1 className="text-balance text-5xl font-semibold tracking-tight text-white sm:text-7xl font-display">
                {heroHeadline}
              </h1>
              <p className="mt-5 text-pretty text-base leading-relaxed text-white/70 sm:text-lg">
                {heroSubhead}
              </p>

              <div className="mt-10 grid gap-3 md:grid-cols-3">
                {downloadButtons.map((item) => (
                  <DownloadButton key={item.os} {...item} />
                ))}
              </div>

              <div className="mt-4 text-xs text-white/55">{heroNote}</div>
            </div>
          </Container>
        </section>

        <section id="screenshots" className="py-16 sm:py-20">
          <Container>
            <SectionHeader
              kicker={sectionLabels.screenshots}
              title="One screen for chat, mail, and calendar"
              subtitle="Real screens from Axichat across desktop and mobile."
            />

            <div className="grid gap-6">
              <ScreenshotCard {...screenshots.desktop[0]} />

              <div className="grid gap-6 lg:grid-cols-2">
                {screenshots.mobile.slice(0, 2).map((item) => (
                  <ScreenshotCard key={item.label} {...item} />
                ))}
              </div>

              <div className="grid gap-6 lg:grid-cols-2">
                {screenshots.mobile.slice(2).map((item) => (
                  <ScreenshotCard key={item.label} {...item} />
                ))}
              </div>

              <div className="grid gap-6 lg:grid-cols-2">
                {screenshots.desktop.slice(1).map((item) => (
                  <ScreenshotCard key={item.label} {...item} />
                ))}
              </div>
            </div>
          </Container>
        </section>

        <section id="features" className="border-y border-white/10 py-16 sm:py-20">
          <Container>
            <SectionHeader
              kicker={sectionLabels.features}
              title="Feature highlights"
              subtitle="If you're proactive and busy, you'll love Axichat both because of what it has and what it doesn't have."
            />

            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              {featureCards.map((feature) => (
                <div key={feature.body} className="rounded-2xl border border-white/10 bg-black/50 p-5">
                  <div className="flex items-start gap-3">
                    <div className="grid h-10 w-10 place-items-center rounded-xl border border-white/10 bg-black text-lg">
                      {feature.emoji}
                    </div>
                    <div className="text-sm leading-relaxed text-white/80">{feature.body}</div>
                  </div>
                </div>
              ))}
            </div>
          </Container>
        </section>

        <section id="why" className="py-16 sm:py-20">
          <Container>
            <SectionHeader kicker="Why?" title="Why Axichat?" />
            <div className="grid gap-4 md:grid-cols-3">
              {whyCards.map((card) => (
                <div key={card.title} className="rounded-2xl border border-white/10 bg-black/50 p-5">
                  <div className="text-sm font-semibold text-white">{card.title}</div>
                  <div className="mt-2 text-sm leading-relaxed text-white/70">{card.body}</div>
                </div>
              ))}
            </div>
          </Container>
        </section>

        <section id="faq" className="py-16 sm:py-20">
          <Container>
            <SectionHeader kicker={sectionLabels.faq} title="Common questions" />
            <div className="flex flex-col gap-4">
              {faqItems.map((item, index) => (
                <FAQItem
                  key={item.question}
                  question={item.question}
                  answer={item.answer}
                  isOpen={openFaqIndex === index}
                  onToggle={() => setOpenFaqIndex(openFaqIndex === index ? null : index)}
                />
              ))}
            </div>
          </Container>
        </section>

        <section id="about" className="border-y border-white/10 py-16 sm:py-20">
          <Container>
            <SectionHeader
              kicker={sectionLabels.about}
              title="A digital desk for your communication"
              subtitle="Built in 2025 in New Zealand. Designed for people who want control of their communications and time."
            />

            <div className="grid gap-4 md:grid-cols-2">
              {aboutCards.map((card) => (
                <div key={card.title} className="rounded-2xl border border-white/10 bg-black/50 p-5">
                  <div className="text-sm font-semibold">{card.title}</div>
                  <ul className="mt-3 space-y-2 text-sm text-white/70">
                    {card.items.map((item) => (
                      <li key={item}>• {item}</li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          </Container>
        </section>

        <section id="contact" className="py-16 sm:py-20">
          <Container>
            <SectionHeader
              kicker={sectionLabels.contact}
              title="Contact us"
              subtitle={
                <>
                  <span>For help and inquiries, reach out to </span>
                  <a href="mailto:support@axichat.com" className="underline underline-offset-4">
                    support@axichat.com
                  </a>
                  <span>. To report bugs or request features please use our </span>
                  <a
                    href="https://github.com/axichat/axichat/issues"
                    target="_blank"
                    rel="noreferrer"
                    className="underline underline-offset-4"
                  >
                    GitHub Issues
                  </a>
                  <span>.</span>
                </>
              }
            />
          </Container>
        </section>

        <footer className="border-t border-white/10 py-10">
          <Container>
            <div className="flex flex-col gap-8 md:flex-row md:items-start md:justify-between">
              <div className="flex flex-col gap-2">
                <div className="flex items-center gap-3">
                  <BrandIcon alt="Axichat" className="h-10 w-10" />
                  <div className="text-lg font-display font-medium leading-none">Axichat</div>
                </div>
                <div className="text-xs text-white/60">© {new Date().getFullYear()} Axichat LLC</div>
                <a href="/LICENSE.txt" className="text-xs text-white/60 hover:text-white">
                  AGPL-3.0
                </a>
              </div>

              <div className="grid gap-8 sm:grid-cols-2 md:grid-cols-3">
                <div className="space-y-3">
                  <div className="text-xs font-semibold uppercase tracking-[0.24em] text-white/60">Sections</div>
                  <div className="flex flex-col gap-2">
                    {footerLinks.sections.map((link) => (
                      <NavLink key={link.href} href={link.href}>
                        {link.label}
                      </NavLink>
                    ))}
                  </div>
                </div>

                <div className="space-y-3">
                  <div className="text-xs font-semibold uppercase tracking-[0.24em] text-white/60">Legal</div>
                  <div className="flex flex-col gap-2">
                    {footerLinks.legal.map((link) => (
                      <a key={link.href} href={link.href} className="text-sm text-white/70 hover:text-white">
                        {link.label}
                      </a>
                    ))}
                  </div>
                </div>

                <div className="space-y-3">
                  <div className="text-xs font-semibold uppercase tracking-[0.24em] text-white/60">Links</div>
                  <div className="flex flex-col gap-2">
                    {footerLinks.links.map((link) => (
                      <a
                        key={link.href}
                        href={link.href}
                        target="_blank"
                        rel="noreferrer"
                        className="text-sm text-white/70 hover:text-white"
                      >
                        {link.label}
                      </a>
                    ))}
                  </div>
                </div>
              </div>
            </div>

          </Container>
        </footer>
      </main>
    </div>
  );
}

import { useState } from "react";

const storeURL = import.meta.env.VITE_APP_STORE_URL?.trim();
const topics = [
  {
    label: "A little perspective",
    question: "What’s changing in clean energy?",
    category: "PLANET · A FRESH PERSPECTIVE",
    image: "planet",
    title: "A brighter kind of energy.",
  },
  {
    label: "Something new",
    question: "Why is everyone talking about AI agents?",
    category: "TECHNOLOGY · THE BIG PICTURE",
    image: "technology",
    title: "Beyond the next big thing.",
  },
  {
    label: "A question for today",
    question: "What happened in the world today?",
    category: "YOUR DAILY FIVE · MADE FOR YOU",
    image: "daily",
    title: "Your world. A little clearer.",
  },
];
function Arrow() {
  return <span aria-hidden="true">↗</span>;
}
function Wave({ active = false }: { active?: boolean }) {
  return (
    <span className={`wave ${active ? "active" : ""}`} aria-hidden="true">
      {[12, 23, 15, 31, 20, 36, 27, 15, 29, 19, 12].map((h, i) => (
        <i key={i} style={{ height: h, animationDelay: `${i * 80}ms` }} />
      ))}
    </span>
  );
}
function StoreLink({ light = false }: { light?: boolean }) {
  return (
    <a
      className={`store-link ${light ? "light" : ""}`}
      href={storeURL || "#download"}
      aria-label={
        storeURL ? "Find told. on the App Store" : "App Store — coming soon"
      }
    >
      <svg
        width="22"
        height="26"
        viewBox="0 0 24 28"
        fill="currentColor"
        aria-hidden="true"
      >
        <path
          d="M16 4c1-1.2 1.6-2.7 1.4-4-1.5.1-3.2 1-4.2 2.2-.9 1-1.7 2.6-1.4 4 1.6.1 3.1-.9 4.2-2.2ZM21 20c-.6 1.4-.9 2.1-1.7 3.4-1.1 1.7-2.6 3.9-4.5 3.9-1.7 0-2.2-1.1-4.5-1.1S7.5 27.3 6 27.3c-1.9 0-3.3-2-4.4-3.7C-1.4 18.8-1.7 12.7.2 9.5 1.5 7.2 3.6 6 5.6 6c2 0 3.2 1.1 4.8 1.1 1.5 0 2.5-1.1 4.8-1.1 1.8 0 3.7 1 5 2.6-4.3 2.4-3.6 8.4.8 11.4Z"
          transform="translate(2 0) scale(.9)"
        />
      </svg>
      <span>
        <small>{storeURL ? "Download on the" : "Coming soon to the"}</small>App
        Store
      </span>
      <Arrow />
    </a>
  );
}
export default function App() {
  const [topic, setTopic] = useState(0);
  const [deepDive, setDeepDive] = useState(false);
  const selected = topics[topic];
  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <header className="header wrap">
        <a href="#" aria-label="told. home">
          <img className="wordmark" src="/images/wordmark.png" alt="told." />
        </a>
        <a className="header-link" href="#download">
          Made for your ears <Arrow />
        </a>
      </header>
      <main id="main">
        <section className="hero wrap">
          <div className="hero-copy">
            <span className="eyebrow">
              <span className="status-dot" /> A LITTLE CLOSER TO THE STORY
            </span>
            <h1>
              Follow your
              <br />
              curiosity<span className="period">.</span>
            </h1>
            <p>
              Your world, worth listening to.
              <br />
              Personal podcasts. Daily perspectives.
              <br />
              Always room for a question.
            </p>
            <StoreLink />
            <span className="availability">
              For iPhone. For the way your mind wanders.
            </span>
          </div>
          <div className="hero-art">
            <img
              src="/images/daily.jpg"
              alt="A sunlit stone bridge stretching across an imagined landscape"
              fetchPriority="high"
            />
            <span className="art-label">A FRESH PERSPECTIVE, EVERY DAY</span>
            <div className="floating-player">
              <div className="player-line">
                <span className="tiny-label">YOUR DAILY FIVE</span>
                <Wave />
              </div>
              <h2>
                A little more world.
                <br />A little less scrolling.
              </h2>
              <div className="player-bottom">
                <span>Five stories. Chosen around you.</span>
                <span className="play-disc" aria-hidden="true">
                  ▶
                </span>
              </div>
            </div>
          </div>
        </section>
        <div className="interlude wrap">
          <span>Less scrolling.</span>
          <span>More understanding.</span>
          <span>Entirely your pace.</span>
        </div>
        <section className="feature wrap" id="curiosity">
          <div className="feature-copy">
            <span className="eyebrow">01 / FOLLOW A THOUGHT</span>
            <h2>
              Turn any curiosity
              <br />
              into a personal
              <br />
              <em>podcast.</em>
            </h2>
            <p>
              A new idea everyone’s talking about. A story you want to
              understand. A question that won’t leave your head.
            </p>
            <p>
              Start with what interests you. Get a clear, personal audio
              explanation that gives you somewhere to begin.
            </p>
            <a className="text-link" href="#topic-preview">
              Find your starting point <span aria-hidden="true">↓</span>
            </a>
          </div>
          <div className="topic-preview" id="topic-preview">
            <div className="topic-image">
              <img
                src={`/images/${selected.image}.jpg`}
                alt=""
                loading="lazy"
              />
              <div className="topic-caption" aria-live="polite">
                <span className="tiny-label">{selected.category}</span>
                <h3>{selected.title}</h3>
              </div>
            </div>
            <div className="topic-options">
              <span className="tiny-label">WHERE SHOULD WE BEGIN?</span>
              {topics.map((item, i) => (
                <button
                  key={item.label}
                  aria-pressed={topic === i}
                  onClick={() => setTopic(i)}
                >
                  <span>{item.question}</span>
                  <Arrow />
                </button>
              ))}
            </div>
          </div>
        </section>
        <section className="listen-section">
          <div className="feature wrap reverse">
            <div className="conversation-preview">
              <div className="conversation-top">
                <span className="tiny-label">
                  ONE CONVERSATION. YOUR DIRECTION.
                </span>
                <span className="preview-label">Interactive preview</span>
              </div>
              <div className="record-disc">
                <Wave active={deepDive} />
              </div>
              <div className="conversation-title" aria-live="polite">
                <span className="tiny-label">
                  {deepDive ? "A LITTLE DEEPER" : "NOW EXPLORING"}
                </span>
                <h3>
                  {deepDive
                    ? "Let’s look at it\nfrom another angle."
                    : "The story behind\nthe headline."}
                </h3>
                <p>
                  {deepDive
                    ? "Your question becomes part of the story."
                    : "A thought comes to mind? Follow it."}
                </p>
              </div>
              <div
                className={`timeline ${deepDive ? "expanded" : ""}`}
                aria-label={
                  deepDive
                    ? "Story, your deep dive, then the story continues"
                    : "Your story timeline"
                }
              >
                <span />
                <i />
                <span className="branch" />
                <i />
                <span />
              </div>
              <div className="timeline-legend">
                <span>Story</span>
                <span className={deepDive ? "purple" : ""}>
                  {deepDive ? "Your deep dive" : "Room for a question"}
                </span>
                <span>Continue</span>
              </div>
              <button
                className="ask-button"
                onClick={() => setDeepDive(!deepDive)}
                aria-pressed={deepDive}
              >
                <span aria-hidden="true">{deepDive ? "↶" : "✳"}</span>
                {deepDive ? "Back to the story" : "Explain that differently"}
              </button>
            </div>
            <div className="feature-copy">
              <span className="eyebrow">02 / MAKE ROOM FOR QUESTIONS</span>
              <h2>
                Audio that actually
                <br />
                <em>listens back.</em>
              </h2>
              <p>Press Ask. The story pauses, and you take it somewhere new.</p>
              <div className="quote-list">
                <span>“Wait, explain that differently.”</span>
                <span>“Give me more technical detail.”</span>
                <span>“Actually, what about this?”</span>
              </div>
              <p>
                Go deeper, change direction, or pick up where you left off. It’s
                all part of the same conversation.
              </p>
            </div>
          </div>
        </section>
        <section className="closing wrap" id="download">
          <span className="eyebrow">A LITTLE CURIOSITY GOES A LONG WAY</span>
          <h2>
            Make space
            <br />
            for a new perspective.
          </h2>
          <StoreLink />
          <p>
            {storeURL
              ? "Your next good question starts here."
              : "Coming soon on iPhone. Good things are taking shape."}
          </p>
        </section>
      </main>
      <footer className="footer wrap">
        <img className="wordmark" src="/images/wordmark.png" alt="told." />
        <span>A little closer to the story.</span>
        <small>© {new Date().getFullYear()} told.</small>
      </footer>
    </>
  );
}

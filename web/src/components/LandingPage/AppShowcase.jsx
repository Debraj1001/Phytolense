// web/src/components/LandingPage/AppShowcase.jsx
import React, { useState } from 'react';
import { Camera, Pill, MessageSquare, Radio, CloudRain, Sprout, CheckCircle, AlertCircle, ArrowRight, Sparkles, Send } from 'lucide-react';

export default function AppShowcase() {
  const [activeTab, setActiveTab] = useState('scanner');

  // Interactive chatbot demo state
  const [chatInput, setChatInput] = useState('');
  const [messages, setMessages] = useState([
    { sender: 'bot', text: 'Namaste! I am PhytoLens Botanist AI. Ask me about crop diseases, dosage calculation, or organic remedies.' },
    { sender: 'user', text: 'My tomato leaves have dark brown target-like concentric rings. What should I spray?' },
    { sender: 'bot', text: 'That matches Early Blight (Alternaria solani). Apply Mancozeb 75% WP @ 2.5g per litre of water. For organic cure, spray 5% neem seed kernel extract (NSKE).' }
  ]);

  const handleSendChat = (e) => {
    e.preventDefault();
    if (!chatInput.trim()) return;
    const userMsg = chatInput;
    setMessages(prev => [...prev, { sender: 'user', text: userMsg }]);
    setChatInput('');

    setTimeout(() => {
      let botReply = 'I recommend inspecting the undersides of the leaves and checking current atmospheric humidity before applying spray.';
      if (userMsg.toLowerCase().includes('spray') || userMsg.toLowerCase().includes('weather')) {
        botReply = 'Current weather conditions are Optimal (24°C, 8 km/h wind, 0% precipitation). You have a safe 6-hour spray window!';
      } else if (userMsg.toLowerCase().includes('organic') || userMsg.toLowerCase().includes('neem')) {
        botReply = 'Organic recipe: Mix 5ml cold-pressed pure neem oil with 2ml liquid soap per 1 litre of warm water. Spray at dusk.';
      } else if (userMsg.toLowerCase().includes('mildew')) {
        botReply = 'For Powdery Mildew: Apply Wettable Sulphur 80% WP @ 3g/L or potassium bicarbonate spray.';
      }
      setMessages(prev => [...prev, { sender: 'bot', text: botReply }]);
    }, 600);
  };

  const tabs = [
    { id: 'scanner', label: '1. Leaf Scanner', icon: Camera, color: 'var(--primary-dark)' },
    { id: 'prescription', label: '2. Curative Recipe', icon: Pill, color: 'var(--secondary)' },
    { id: 'chatbot', label: '3. Botanist AI Chat', icon: MessageSquare, color: 'var(--accent-amber)' },
    { id: 'radar', label: '4. Outbreak Radar', icon: Radio, color: '#DC2626' },
    { id: 'spray', label: '5. Spray Window', icon: CloudRain, color: '#0284C7' },
    { id: 'garden', label: '6. Garden Vault', icon: Sprout, color: 'var(--primary)' }
  ];

  return (
    <section id="showcase" className="section-py" style={{ position: 'relative' }}>
      <div className="container">
        {/* Header */}
        <div style={{ textAlign: 'center', maxWidth: '820px', margin: '0 auto 44px auto' }}>
          <span className="badge badge-emerald" style={{ marginBottom: '12px' }}>
            Interactive App Viewing
          </span>
          <h2 style={{ fontSize: 'clamp(28px, 4vw, 42px)', marginBottom: '16px' }}>
            Experience PhytoLens In Action
          </h2>
          <p style={{ fontSize: '16px' }}>
            Explore the exact mobile workflows built into the Flutter app: from capturing leaf pathology to calculating precision chemical dosage and reviewing outbreak maps.
          </p>
        </div>

        {/* Tab Switcher Pills */}
        <div style={{
          display: 'flex',
          justifyContent: 'center',
          flexWrap: 'wrap',
          gap: '10px',
          marginBottom: '36px'
        }}>
          {tabs.map(t => {
            const Icon = t.icon;
            const isSelected = activeTab === t.id;
            return (
              <button
                key={t.id}
                onClick={() => setActiveTab(t.id)}
                className={`btn ${isSelected ? 'btn-primary' : 'btn-white'}`}
                style={{
                  padding: '8px 16px',
                  fontSize: '13px'
                }}
              >
                <Icon size={16} />
                <span>{t.label}</span>
              </button>
            );
          })}
        </div>

        {/* Showcase Grid */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
          gap: '32px',
          alignItems: 'center'
        }}>
          {/* Left: Phone Device Mockup */}
          <div style={{ display: 'flex', justifyContent: 'center' }}>
            <div style={{
              width: '100%',
              maxWidth: '340px',
              height: '620px',
              backgroundColor: '#0F172A',
              borderRadius: '40px',
              border: '4px solid #0F172A',
              boxShadow: 'var(--shadow-xl)',
              padding: '12px',
              position: 'relative',
              overflow: 'hidden'
            }}>
              {/* Phone Speaker Notch */}
              <div style={{
                position: 'absolute',
                top: '16px',
                left: '50%',
                transform: 'translateX(-50%)',
                width: '110px',
                height: '20px',
                backgroundColor: '#0F172A',
                borderRadius: '12px',
                zIndex: 20
              }} />

              {/* Phone Screen Canvas */}
              <div style={{
                width: '100%',
                height: '100%',
                backgroundColor: '#F8FAFC',
                borderRadius: '28px',
                overflow: 'hidden',
                display: 'flex',
                flexDirection: 'column',
                fontFamily: 'var(--font-sans)',
                position: 'relative'
              }}>
                {/* Status Bar */}
                <div style={{
                  height: '38px',
                  padding: '8px 18px 0 18px',
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  fontSize: '11px',
                  fontWeight: 700,
                  color: '#0F172A',
                  backgroundColor: '#FFFFFF',
                  borderBottom: '1px solid #E2E8F0'
                }}>
                  <span>9:41</span>
                  <span>5G 📶 100%</span>
                </div>

                {/* Active Screen Content */}
                <div style={{ flex: 1, overflowY: 'auto', padding: '16px' }}>
                  {activeTab === 'scanner' && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                      <div style={{
                        height: '240px',
                        backgroundColor: '#1E293B',
                        borderRadius: '16px',
                        border: '2px solid #0F172A',
                        position: 'relative',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        overflow: 'hidden',
                        background: 'linear-gradient(135deg, #14532D 0%, #166534 100%)'
                      }}>
                        <span style={{ fontSize: '64px' }}>🍃</span>
                        {/* Bounding Box Overlay */}
                        <div style={{
                          position: 'absolute',
                          top: '30px',
                          left: '40px',
                          right: '40px',
                          bottom: '30px',
                          border: '2.5px dashed #34D399',
                          borderRadius: '12px',
                          boxShadow: '0 0 14px rgba(52, 211, 153, 0.4)'
                        }} />
                        <div style={{
                          position: 'absolute',
                          bottom: '10px',
                          left: '10px',
                          backgroundColor: '#0F172A',
                          color: '#FFFFFF',
                          padding: '4px 8px',
                          borderRadius: '6px',
                          fontSize: '11px',
                          fontWeight: 700
                        }}>
                          Early Blight (94.2% Conf.)
                        </div>
                      </div>

                      <div className="neo-card-subtle" style={{ padding: '12px' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px' }}>
                          <span style={{ fontWeight: 700, fontSize: '13px' }}>Tomato Early Blight</span>
                          <span className="badge badge-amber" style={{ fontSize: '10px' }}>Stage 2 · Moderate</span>
                        </div>
                        <p style={{ fontSize: '11px', color: '#475569' }}>
                          Alternaria solani detected. Fungus causing circular dark brown spots with concentric concentric rings.
                        </p>
                      </div>

                      <button className="btn btn-primary btn-sm" style={{ width: '100%' }}>
                        View Curative Agronomy Recipe →
                      </button>
                    </div>
                  )}

                  {activeTab === 'prescription' && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                      <div style={{
                        padding: '12px',
                        backgroundColor: '#ECFDF5',
                        border: '2px solid #0F172A',
                        borderRadius: '12px'
                      }}>
                        <span className="badge badge-emerald" style={{ fontSize: '10px', marginBottom: '6px' }}>
                          Groq LLaMA-3 Prescribed
                        </span>
                        <h4 style={{ fontSize: '14px', marginBottom: '4px' }}>Chemical Intervention</h4>
                        <div style={{ fontSize: '11px', color: '#065F46' }}>
                          <b>Active:</b> Mancozeb 75% WP<br/>
                          <b>Dosage:</b> 2.5g / 1 Litre of clean water<br/>
                          <b>Frequency:</b> Every 7–10 days until dry
                        </div>
                      </div>

                      <div style={{
                        padding: '12px',
                        backgroundColor: '#FFFBEB',
                        border: '2px solid #0F172A',
                        borderRadius: '12px'
                      }}>
                        <span className="badge badge-amber" style={{ fontSize: '10px', marginBottom: '6px' }}>
                          Organic Homemade Alternative
                        </span>
                        <h4 style={{ fontSize: '14px', marginBottom: '4px' }}>Neem Bio-Extract</h4>
                        <div style={{ fontSize: '11px', color: '#92400E' }}>
                          5ml pure neem oil + 2ml liquid dish soap in 1L water. Spray thoroughly under foliage at sundown.
                        </div>
                      </div>

                      <div style={{
                        padding: '10px',
                        backgroundColor: '#F1F5F9',
                        borderRadius: '8px',
                        fontSize: '11px',
                        border: '1.5px solid #0F172A'
                      }}>
                        🏪 <b>Nearby Stockist:</b> Kisan Agro Inputs (2.3 km) · 📞 Direct Call Ready
                      </div>
                    </div>
                  )}

                  {activeTab === 'chatbot' && (
                    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
                      <div style={{
                        flex: 1,
                        display: 'flex',
                        flexDirection: 'column',
                        gap: '8px',
                        overflowY: 'auto',
                        paddingBottom: '8px'
                      }}>
                        {messages.map((m, idx) => (
                          <div
                            key={idx}
                            style={{
                              alignSelf: m.sender === 'user' ? 'flex-end' : 'flex-start',
                              backgroundColor: m.sender === 'user' ? 'var(--primary)' : '#FFFFFF',
                              color: '#0F172A',
                              padding: '8px 12px',
                              borderRadius: '12px',
                              border: '1.5px solid #0F172A',
                              fontSize: '11px',
                              maxWidth: '85%',
                              lineHeight: 1.4
                            }}
                          >
                            {m.text}
                          </div>
                        ))}
                      </div>

                      <form onSubmit={handleSendChat} style={{ display: 'flex', gap: '6px', marginTop: 'auto' }}>
                        <input
                          type="text"
                          value={chatInput}
                          onChange={(e) => setChatInput(e.target.value)}
                          placeholder="Ask agronomist..."
                          style={{
                            flex: 1,
                            padding: '6px 10px',
                            fontSize: '11px',
                            border: '1.5px solid #0F172A',
                            borderRadius: '8px'
                          }}
                        />
                        <button type="submit" className="btn btn-primary btn-sm" style={{ padding: '6px 8px' }}>
                          <Send size={12} />
                        </button>
                      </form>
                    </div>
                  )}

                  {activeTab === 'radar' && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                      <div style={{
                        height: '180px',
                        backgroundColor: '#E2E8F0',
                        borderRadius: '12px',
                        border: '2px solid #0F172A',
                        position: 'relative',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        overflow: 'hidden'
                      }}>
                        <div style={{
                          width: '120px',
                          height: '120px',
                          borderRadius: '50%',
                          border: '2px solid rgba(239, 68, 68, 0.4)',
                          backgroundColor: 'rgba(239, 68, 68, 0.1)',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center'
                        }}>
                          <span className="pulse-dot" style={{ backgroundColor: '#EF4444', width: '14px', height: '14px' }} />
                        </div>
                        <div style={{
                          position: 'absolute',
                          top: '8px',
                          left: '8px',
                          backgroundColor: '#FFFFFF',
                          padding: '4px 8px',
                          borderRadius: '6px',
                          fontSize: '10px',
                          fontWeight: 700,
                          border: '1px solid #0F172A'
                        }}>
                          10 km Outbreak Radius
                        </div>
                      </div>

                      <div className="neo-card-subtle" style={{ padding: '10px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
                          <span className="badge badge-red" style={{ fontSize: '9px' }}>Alert</span>
                          <span style={{ fontSize: '12px', fontWeight: 700 }}>Late Blight Cluster</span>
                        </div>
                        <p style={{ fontSize: '10px', color: '#475569' }}>
                          3 neighboring farms within 4.2 km reported active Phytophthora infestans. Spray preventative bio-fungicide immediately.
                        </p>
                      </div>
                    </div>
                  )}

                  {activeTab === 'spray' && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                      <div style={{
                        padding: '14px',
                        backgroundColor: '#ECFDF5',
                        border: '2px solid #0F172A',
                        borderRadius: '14px',
                        textAlign: 'center'
                      }}>
                        <span className="badge badge-emerald" style={{ fontSize: '11px' }}>Spray Window Status</span>
                        <div style={{ fontSize: '24px', fontWeight: 800, marginTop: '8px', color: 'var(--primary-dark)' }}>
                          OPTIMAL ✓
                        </div>
                        <p style={{ fontSize: '11px', color: '#047857', marginTop: '4px' }}>
                          Safe application window next 6 hours. Zero rain forecasted.
                        </p>
                      </div>

                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                        <div className="neo-card-subtle" style={{ padding: '8px', textAlign: 'center' }}>
                          <div style={{ fontSize: '10px', color: '#64748B' }}>Temperature</div>
                          <div style={{ fontSize: '16px', fontWeight: 800 }}>24.5 °C</div>
                        </div>
                        <div className="neo-card-subtle" style={{ padding: '8px', textAlign: 'center' }}>
                          <div style={{ fontSize: '10px', color: '#64748B' }}>Humidity</div>
                          <div style={{ fontSize: '16px', fontWeight: 800 }}>62 %</div>
                        </div>
                        <div className="neo-card-subtle" style={{ padding: '8px', textAlign: 'center' }}>
                          <div style={{ fontSize: '10px', color: '#64748B' }}>Wind Velocity</div>
                          <div style={{ fontSize: '16px', fontWeight: 800 }}>8 km/h</div>
                        </div>
                        <div className="neo-card-subtle" style={{ padding: '8px', textAlign: 'center' }}>
                          <div style={{ fontSize: '10px', color: '#64748B' }}>Rain Risk</div>
                          <div style={{ fontSize: '16px', fontWeight: 800, color: 'var(--primary-dark)' }}>0 %</div>
                        </div>
                      </div>
                    </div>
                  )}

                  {activeTab === 'garden' && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                      <div className="neo-card-subtle" style={{ padding: '10px', display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <div style={{ fontSize: '28px' }}>🍅</div>
                        <div style={{ flex: 1 }}>
                          <div style={{ fontSize: '12px', fontWeight: 700 }}>Tomato Plot A (North Field)</div>
                          <div style={{ fontSize: '10px', color: 'var(--primary-dark)' }}>Recovery: 85% · Mild Blight Healing</div>
                        </div>
                      </div>
                      <div className="neo-card-subtle" style={{ padding: '10px', display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <div style={{ fontSize: '28px' }}>🥔</div>
                        <div style={{ flex: 1 }}>
                          <div style={{ fontSize: '12px', fontWeight: 700 }}>Potato Seedlings (Bed 3)</div>
                          <div style={{ fontSize: '10px', color: 'var(--primary-dark)' }}>100% Healthy · Last Scanned Today</div>
                        </div>
                      </div>
                      <div className="neo-card-subtle" style={{ padding: '10px', display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <div style={{ fontSize: '28px' }}>🌶️</div>
                        <div style={{ flex: 1 }}>
                          <div style={{ fontSize: '12px', fontWeight: 700 }}>Chilli Nursery</div>
                          <div style={{ fontSize: '10px', color: 'var(--accent-amber)' }}>Thrips Monitored · Bio-spray applied</div>
                        </div>
                      </div>
                    </div>
                  )}
                </div>

                {/* Bottom App Navigation Bar */}
                <div style={{
                  height: '52px',
                  backgroundColor: '#FFFFFF',
                  borderTop: '2px solid #0F172A',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-around',
                  padding: '0 8px',
                  fontSize: '18px'
                }}>
                  <span style={{ cursor: 'pointer' }}>🏠</span>
                  <span style={{ cursor: 'pointer' }}>📸</span>
                  <span style={{ cursor: 'pointer' }}>🤖</span>
                  <span style={{ cursor: 'pointer' }}>🪴</span>
                  <span style={{ cursor: 'pointer' }}>👤</span>
                </div>
              </div>
            </div>
          </div>

          {/* Right: Feature Descriptions */}
          <div>
            <span className="badge badge-mint" style={{ marginBottom: '12px' }}>
              Full Operational Capabilities
            </span>
            <h3 style={{ fontSize: '28px', marginBottom: '14px' }}>
              {activeTab === 'scanner' && 'Real-Time Edge & Cloud Pathology Detection'}
              {activeTab === 'prescription' && 'Agronomic Protocols with Active Ingredients'}
              {activeTab === 'chatbot' && 'Interactive Botanist AI Consultation'}
              {activeTab === 'radar' && '10 km Radius Epidemic Warning Telemetry'}
              {activeTab === 'spray' && 'Weather-Driven Spray Timing Advisory'}
              {activeTab === 'garden' && 'Digital Plot Vault & Crop Healing Progress'}
            </h3>

            <p style={{ fontSize: '16px', color: 'var(--text-secondary)', marginBottom: '24px', lineHeight: 1.6 }}>
              {activeTab === 'scanner' && 
                'Takes a photo of any damaged crop leaf. Runs immediate inference through on-device TFLite models or rotated Gemini Vision API to identify 38+ plant diseases within 1.2 seconds, even when working completely offline in rural fields.'}
              {activeTab === 'prescription' && 
                'Generates precise agronomic treatment plans using ultra-fast Groq LLaMA-3. Provides exact chemical names, active ingredient percentages, application dilution ratios, personal protective equipment rules, and kitchen-made organic bio-sprays.'}
              {activeTab === 'chatbot' && 
                'Trained on extensive agronomic datasets. Farmers can chat naturally in English or Hindi to calculate chemical dilution quantities, troubleshoot yellowing leaves, or seek guidance on pest mitigation.'}
              {activeTab === 'radar' && 
                'Aggregates anonymized diagnoses across a 10km geographic perimeter. Automatically alerts nearby farmers when airborne fungal spores (like Late Blight) are detected in neighboring fields, enabling preventative bio-spraying.'}
              {activeTab === 'spray' && 
                'Live meteorological telemetry checks temperature, humidity, wind velocity, and precipitation probability. Warns against chemical applications before rainstorms or in heavy winds to prevent toxic runoff and wasted farmer investment.'}
              {activeTab === 'garden' && 
                'Track multiple crop plots, custom watering schedules, and disease healing trajectories. Voice Read-Aloud allows farmers to listen to treatment steps without taking their muddy hands off field tools.'}
            </p>

            <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
              <a href="#download-qr" className="btn btn-primary btn-sm">
                <span>Download App to Try →</span>
              </a>
              <button 
                onClick={() => {
                  const nextIdx = (tabs.findIndex(t => t.id === activeTab) + 1) % tabs.length;
                  setActiveTab(tabs[nextIdx].id);
                }}
                className="btn btn-white btn-sm"
              >
                <span>Next Feature Showcase →</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

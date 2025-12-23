// Privacy Policy Page Component
import React from 'react';

const PrivacyPolicyPage = ({ setCurrentPage, previousPage }) => {
    const handleBack = () => {
      // Navigate back to previous page, or fallback to home
      const targetPage = previousPage || 'home';
      setCurrentPage(targetPage);
    };

    return (
      <div className="container mx-auto py-8 px-4 max-w-4xl">
        <button 
          className="mb-4 flex items-center text-emerald-600 hover:underline"
          onClick={handleBack}
        >
          <svg className="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 19l-7-7 7-7"></path>
          </svg>
          Back
        </button>
        
        <div className="bg-white rounded-lg shadow-md p-8">
          <div className="flex items-center gap-3 mb-6">
            <h1 className="text-3xl font-bold">Privacy Policy</h1>
          </div>
          
          <p className="text-gray-600 mb-8">Last updated: December 22, 2025</p>
          
          <div className="space-y-6">
            <section>
              <h2 className="text-2xl font-semibold mb-3">Account Security</h2>
              <p className="text-gray-700 leading-relaxed mb-3">
                We use passwordless authentication for enhanced security. When you log in, we send a one-time code (OTP) to your email.
              </p>
              <div className="bg-emerald-50 border-l-4 border-emerald-600 p-4 mb-3">
                <h3 className="font-semibold mb-2 text-emerald-900">How Passwordless Login Works:</h3>
                <ul style={{ listStyleType: 'disc', listStylePosition: 'inside', paddingLeft: '1rem' }} className="text-emerald-800 space-y-1 ml-2">
                  <li>Enter your email address to request a login code</li>
                  <li>We send a unique, temporary code to your email</li>
                  <li>Enter the code to securely access your account</li>
                  <li>The code expires after a short time and can only be used once</li>
                </ul>
              </div>
              <p className="text-gray-700 leading-relaxed mb-3">
                This approach is more secure than traditional passwords because:
              </p>
              <ul style={{ listStyleType: 'disc', listStylePosition: 'inside', paddingLeft: '1rem' }} className="text-gray-700 space-y-1 ml-4">
                <li>No passwords to remember, steal, or compromise</li>
                <li>Each login requires access to your email account</li>
                <li>Codes are temporary and expire quickly</li>
                <li>No password database that could be breached</li>
              </ul>
              <p className="text-gray-700 leading-relaxed mt-3">
                <strong>Your Responsibilities:</strong>
              </p>
              <ul style={{ listStyleType: 'disc', listStylePosition: 'inside', paddingLeft: '1rem' }} className="text-gray-700 space-y-1 ml-4">
                <li>Keep your email account secure</li>
                <li>Do not share login codes with anyone</li>
                <li>You are responsible for all activity under your account</li>
                <li>Notify us immediately if you suspect unauthorized access</li>
              </ul>
            </section>
            
            <section>
              <h2 className="text-2xl font-semibold mb-3">Our Commitment to Your Privacy</h2>
              <div className="bg-emerald-50 border-l-4 border-emerald-600 p-4 mb-4">
                <p className="text-emerald-900 font-medium">
                  We will NEVER sell, rent, or share your personal information with third parties for marketing purposes.
                </p>
              </div>
              <p className="text-gray-700 leading-relaxed mb-3">
                BookShare Community is operated by SimplifAI LLC and built on trust. We believe your personal information belongs to you, 
                and we're committed to protecting it. This policy explains what information we collect, how we use it, and your rights 
                regarding your data.
              </p>
              <p className="text-gray-700 leading-relaxed">
                BookShare Community is a small, independently-operated service. We collect only the minimum information necessary to 
                connect book donors with recipients in local communities.
              </p>
            </section>
            
            <section>
              <h2 className="text-2xl font-semibold mb-3">Information We Collect</h2>
              <div className="bg-gray-50 rounded-md p-4">
                <h3 className="font-semibold mb-2">Account Information:</h3>
                <ul style={{ listStyleType: 'disc', listStylePosition: 'inside', paddingLeft: '1rem' }} className="text-gray-700 space-y-1 ml-2">
                  <li>Name (to identify you to other users when arranging book exchanges)</li>
                  <li>Email address (for account verification and one-time login codes)</li>
                  <li>ZIP code (to show books available in your local area)</li>
                  <li>Auto-generated encrypted password (created automatically by our system and stored securely - you never see or use this)</li>
                </ul>
                <p className="text-sm text-gray-600 mt-2 italic">
                  Note: We use passwordless authentication with one-time codes sent to your email. While a password is generated and encrypted in our database for technical purposes, you never interact with it - all logins use temporary email codes.
                </p>
              </div>
              <div className="bg-gray-50 rounded-md p-4 mt-3">
                <h3 className="font-semibold mb-2">Book Listings:</h3>
                <ul style={{ listStyleType: 'disc', listStylePosition: 'inside', paddingLeft: '1rem' }} className="text-gray-700 space-y-1 ml-2">
                  <li>Book details (title, author, condition, description)</li>
                  <li>Book cover images you upload</li>
                  <li>Your approximate location (ZIP code only)</li>
                </ul>
              </div>
              <div className="bg-gray-50 rounded-md p-4 mt-3">
                <h3 className="font-semibold mb-2">Communications:</h3>
                <ul style={{ listStyleType: 'disc', listStylePosition: 'inside', paddingLeft: '1rem' }} className="text-gray-700 space-y-1 ml-2">
                  <li>Messages exchanged through our secure messaging system</li>
                  <li>Support inquiries and correspondence</li>
                </ul>
              </div>
            </section>
            
            <section>
              <h2 className="text-2xl font-semibold mb-3">How We Use Your Information</h2>
              <p className="text-gray-700 leading-relaxed mb-3">
                We use your information solely to provide and improve our book donation service:
              </p>
              <div className="space-y-3">
                <div className="flex items-start gap-3">
                  <div className="bg-emerald-100 rounded-full p-2 mt-1">
                    <svg className="w-4 h-4 text-emerald-700" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd"></path>
                    </svg>
                  </div>
                  <div>
                    <h3 className="font-semibold">Connect Local Readers</h3>
                    <p className="text-gray-700">Show you books available in your area and connect you with donors</p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3">
                  <div className="bg-emerald-100 rounded-full p-2 mt-1">
                    <svg className="w-4 h-4 text-emerald-700" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd"></path>
                    </svg>
                  </div>
                  <div>
                    <h3 className="font-semibold">Facilitate Safe Exchanges</h3>
                    <p className="text-gray-700">Enable secure communication between donors and recipients</p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3">
                  <div className="bg-emerald-100 rounded-full p-2 mt-1">
                    <svg className="w-4 h-4 text-emerald-700" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd"></path>
                    </svg>
                  </div>
                  <div>
                    <h3 className="font-semibold">Improve Our Service</h3>
                    <p className="text-gray-700">Understand how our platform is used to make it better for everyone</p>
                  </div>
                </div>
                
                <div className="flex items-start gap-3">
                  <div className="bg-emerald-100 rounded-full p-2 mt-1">
                    <svg className="w-4 h-4 text-emerald-700" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd"></path>
                    </svg>
                  </div>
                  <div>
                    <h3 className="font-semibold">Send Essential Communications</h3>
                    <p className="text-gray-700">Notify you about book requests, messages, and important account updates</p>
                  </div>
                </div>
              </div>
            </section>
            
            <section>
              <h2 className="text-2xl font-semibold mb-3">What We DON'T Do</h2>
              <div className="bg-red-50 border-l-4 border-red-500 p-4">
                <ul className="space-y-2 text-gray-800">
                  <li className="flex items-start gap-2">
                    <span className="text-red-600 font-bold">✗</span>
                    <span>Sell your information to advertisers or data brokers</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <span className="text-red-600 font-bold">✗</span>
                    <span>Share your email with marketing companies</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <span className="text-red-600 font-bold">✗</span>
                    <span>Track you across other websites</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <span className="text-red-600 font-bold">✗</span>
                    <span>Show you targeted advertisements</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <span className="text-red-600 font-bold">✗</span>
                    <span>Share your personal details without your explicit consent</span>
                  </li>
                </ul>
              </div>
            </section>
            
            <section>
              <h2 className="text-2xl font-semibold mb-3">Information Sharing</h2>
              <p className="text-gray-700 leading-relaxed mb-3">
                Your information is shared only in these specific circumstances:
              </p>
              <div className="space-y-2">
                <div className="bg-blue-50 rounded-md p-3">
                  <p className="font-semibold text-blue-900 mb-1">With Other Users (Limited)</p>
                  <p className="text-blue-800 text-sm">
                    When you list a book or express interest in one, your name and general location (ZIP code) are visible 
                    to facilitate the exchange. Your email is never shared publicly.
                  </p>
                </div>
                <div className="bg-blue-50 rounded-md p-3">
                  <p className="font-semibold text-blue-900 mb-1">Service Providers</p>
                  <p className="text-blue-800 text-sm">
                    We use trusted third-party services (hosting, email delivery) who are contractually obligated to protect 
                    your data and use it only for providing our service to you.
                  </p>
                </div>
                <div className="bg-blue-50 rounded-md p-3">
                  <p className="font-semibold text-blue-900 mb-1">Legal Requirements</p>
                  <p className="text-blue-800 text-sm">
                    We may disclose information if required by law, court order, or to protect the rights and safety of our users.
                  </p>
                </div>
              </div>
            </section>
            
            <section>
              <h2 className="text-2xl font-semibold mb-3">Your Rights</h2>
              <p className="text-gray-700 leading-relaxed mb-3">
                You have complete control over your data:
              </p>
              <div className="grid md:grid-cols-2 gap-3">
                <div className="border border-gray-200 rounded-md p-4">
                  <h3 className="font-semibold mb-2">Access Your Data</h3>
                  <p className="text-gray-700 text-sm">Request a copy of all information we have about you</p>
                </div>
                <div className="border border-gray-200 rounded-md p-4">
                  <h3 className="font-semibold mb-2">Update Information</h3>
                  <p className="text-gray-700 text-sm">Change your profile details at any time</p>
                </div>
                <div className="border border-gray-200 rounded-md p-4">
                  <h3 className="font-semibold mb-2">Delete Your Account</h3>
                  <p className="text-gray-700 text-sm">Remove all your information from our platform permanently</p>
                </div>
                <div className="border border-gray-200 rounded-md p-4">
                  <h3 className="font-semibold mb-2">Export Your Data</h3>
                  <p className="text-gray-700 text-sm">Download your book listings and message history</p>
                </div>
              </div>
            </section>
            
            <section>
              <h2 className="text-2xl font-semibold mb-3">Data Security</h2>
              <p className="text-gray-700 leading-relaxed mb-3">
                We implement industry-standard security measures to protect your information:
              </p>
              <ul style={{ listStyleType: 'disc', listStylePosition: 'inside', paddingLeft: '1rem' }} className="text-gray-700 space-y-2 ml-4">
                <li><strong>Passwordless Authentication:</strong> We use one-time codes sent to your email instead of storing passwords, eliminating the risk of password breaches</li>
                <li><strong>Encrypted Connections:</strong> All data transmission uses secure HTTPS connections</li>
                <li><strong>Temporary Codes:</strong> Login codes expire after a short time and can only be used once</li>
                <li><strong>Regular Updates:</strong> We maintain security updates and monitoring</li>
                <li><strong>Limited Access:</strong> Strict controls on access to personal information</li>
              </ul>
              <p className="text-gray-700 leading-relaxed mt-3">
                However, no method of transmission over the internet is 100% secure, and we cannot guarantee absolute security.
              </p>
            </section>
            
            <section>
              <h2 className="text-2xl font-semibold mb-3">Children's Privacy</h2>
              <p className="text-gray-700 leading-relaxed">
                BookShare Community is not intended for users under 13 years of age. We do not knowingly collect information 
                from children under 13. If you are a parent or guardian and believe your child has provided us with personal 
                information, please contact us immediately.
              </p>
            </section>
            
            <section>
              <h2 className="text-2xl font-semibold mb-3">Changes to This Policy</h2>
              <p className="text-gray-700 leading-relaxed">
                We may update this privacy policy from time to time. We will notify you of any significant changes by email 
                and by posting a notice on our website. Your continued use of BookShare Community after such changes 
                constitutes acceptance of the updated policy.
              </p>
            </section>
            
            <section className="bg-emerald-50 border border-emerald-200 rounded-md p-6">
              <h2 className="text-2xl font-semibold mb-3">Contact Us</h2>
              <p className="text-gray-700 leading-relaxed mb-3">
                Have questions about your privacy or this policy? We're here to help.
              </p>
              <div className="space-y-2 text-gray-700">
                <p><strong>Email:</strong> privacy@booksharecommunity.org</p>
                <p><strong>Website:</strong> booksharecommunity.org</p>
                <p className="text-sm text-gray-600 mt-3">
                  BookShare Community is operated by SimplifAI LLC
                </p>
              </div>
            </section>
          </div>
        </div>
      </div>
    );
  };

  export default PrivacyPolicyPage;
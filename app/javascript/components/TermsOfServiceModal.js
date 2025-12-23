// Terms of Service Modal Component
import React from 'react';
import Modal from './Modal';

const TermsOfServiceModal = ({ isOpen, onClose }) => {
  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Terms of Service">
      <div className="space-y-6">
        <p className="text-gray-600">Last updated: December 22, 2025</p>
        
        <section>
          <h2 className="text-2xl font-semibold mb-3">Welcome to BookShare Community</h2>
          <p className="text-gray-700 leading-relaxed mb-3">
            These Terms of Service govern your use of BookShare Community, operated by SimplifAI LLC. By creating an account 
            and using our service, you agree to these terms. Please read them carefully.
          </p>
          <p className="text-gray-700 leading-relaxed">
            BookShare Community is an independently-operated platform designed to foster local book sharing and community building.
          </p>
        </section>
        
        <section>
          <h2 className="text-2xl font-semibold mb-3">Our Service</h2>
          <p className="text-gray-700 leading-relaxed">
            BookShare Community is a free platform that connects people who want to donate books with those who want to 
            receive them. We provide the technology to facilitate these connections, but we are not party to the actual 
            exchange of books between users.
          </p>
        </section>
        
        <section>
          <h2 className="text-2xl font-semibold mb-3">User Responsibilities</h2>
          <div className="bg-gray-50 rounded-md p-4 space-y-3">
            <div>
              <h3 className="font-semibold mb-1">Accurate Information</h3>
              <p className="text-gray-700 text-sm">You agree to provide accurate information about yourself and the books you list.</p>
            </div>
            <div>
              <h3 className="font-semibold mb-1">Safe Meetings</h3>
              <p className="text-gray-700 text-sm">When exchanging books, meet in public places and take appropriate safety precautions.</p>
            </div>
            <div>
              <h3 className="font-semibold mb-1">Respectful Conduct</h3>
              <p className="text-gray-700 text-sm">Treat other users with respect and courtesy. Harassment will not be tolerated.</p>
            </div>
            <div>
              <h3 className="font-semibold mb-1">Book Condition</h3>
              <p className="text-gray-700 text-sm">Honestly represent the condition of books you're donating.</p>
            </div>
          </div>
        </section>
        
        <section>
          <h2 className="text-2xl font-semibold mb-3">Prohibited Activities</h2>
          <p className="text-gray-700 leading-relaxed mb-3">You may not:</p>
          <ul style={{ listStyleType: 'disc', listStylePosition: 'inside', paddingLeft: '1rem' }} className="text-gray-700 space-y-2 ml-4">
            <li>Sell books or request money for donations</li>
            <li>List books you don't actually possess</li>
            <li>Use the platform for any commercial purpose</li>
            <li>Harass, threaten, or harm other users</li>
            <li>Share inappropriate or offensive content</li>
            <li>Attempt to gain unauthorized access to other accounts</li>
          </ul>
        </section>
        
        <section>
          <h2 className="text-2xl font-semibold mb-3">Limitation of Liability</h2>
          <p className="text-gray-700 leading-relaxed mb-3">
            BookShare Community is a platform that connects users. SimplifAI LLC is not responsible for:
          </p>
          <ul style={{ listStyleType: 'disc', listStylePosition: 'inside', paddingLeft: '1rem' }} className="text-gray-700 space-y-2 ml-4">
            <li>The actual exchange of books between users</li>
            <li>The condition, content, or legality of donated books</li>
            <li>Any interactions, disputes, or arrangements between users</li>
            <li>Any injuries, losses, or damages resulting from book exchanges</li>
          </ul>
          <p className="text-gray-700 leading-relaxed mt-3">
            You use this service at your own risk and are responsible for your own safety when meeting other users.
          </p>
        </section>
        
        <section>
          <h2 className="text-2xl font-semibold mb-3">Account Termination</h2>
          <p className="text-gray-700 leading-relaxed">
            We reserve the right to suspend or terminate accounts that violate these terms or engage in behavior that 
            harms the community.
          </p>
        </section>
        
        <section className="bg-blue-50 border border-blue-200 rounded-md p-6">
          <h2 className="text-2xl font-semibold mb-3">Questions?</h2>
          <p className="text-gray-700 leading-relaxed mb-3">
            If you have questions about these terms, please contact us:
          </p>
          <p className="text-gray-700">
            <strong>Email:</strong> support@booksharecommunity.org
          </p>
          <p className="text-sm text-gray-600 mt-3">
            BookShare Community is operated by SimplifAI LLC
          </p>
        </section>
      </div>
    </Modal>
  );
};

export default TermsOfServiceModal;


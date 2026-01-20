import React, { useEffect, useMemo, useRef, useState } from 'react';
import axios from '../../lib/axios';
import { useAuth } from '../../contexts/AuthContext';

const TABS = [
  { key: 'current', label: 'Current' },
  { key: 'requested', label: 'Requested' },
  { key: 'invites', label: 'Invites' },
];

const MyGroups = ({ currentUser, setCurrentPage }) => {
  const { checkAuthStatus } = useAuth();
  const [activeTab, setActiveTab] = useState('current');
  const [loading, setLoading] = useState(false);
  const [currentGroups, setCurrentGroups] = useState([]);
  const [requested, setRequested] = useState([]);
  const [invites, setInvites] = useState([]);
  const [updatingSubGroupMembershipId, setUpdatingSubGroupMembershipId] = useState(null);

  // Public group search
  const [searchInput, setSearchInput] = useState('');
  const [suggestions, setSuggestions] = useState([]);
  const [selectedGroup, setSelectedGroup] = useState(null);
  const [joinMessage, setJoinMessage] = useState('');
  const [requestingJoin, setRequestingJoin] = useState(false);
  const debounceRef = useRef(null);

  const counts = useMemo(() => ({
    current: currentGroups.length,
    requested: requested.length,
    invites: invites.length,
  }), [currentGroups.length, requested.length, invites.length]);

  const loadAll = async () => {
    setLoading(true);
    try {
      const [cur, req, inv] = await Promise.all([
        axios.get('/api/my_groups', { withCredentials: true }),
        axios.get('/api/my_groups/requests', { withCredentials: true }),
        axios.get('/api/my_groups/invites', { withCredentials: true }),
      ]);
      setCurrentGroups(cur.data || []);
      setRequested(req.data || []);
      setInvites(inv.data || []);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    // Allow deep-linking from email: /my-groups?tab=invites
    const tab = new URLSearchParams(window.location.search).get('tab');
    if (tab && ['current', 'requested', 'invites'].includes(tab)) {
      setActiveTab(tab);
    }
  }, []);

  useEffect(() => {
    if (currentUser) {
      loadAll();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentUser?.id]);

  useEffect(() => {
    // Once a group is selected, stop autocomplete queries and keep dropdown closed.
    if (selectedGroup) {
      setSuggestions([]);
      return;
    }

    if (!searchInput.trim()) {
      setSuggestions([]);
      return;
    }

    if (debounceRef.current) {
      clearTimeout(debounceRef.current);
    }

    debounceRef.current = setTimeout(async () => {
      try {
        const res = await axios.get('/api/community_groups', {
          params: { q: searchInput },
          withCredentials: true,
        });
        setSuggestions(res.data || []);
      } catch (e) {
        setSuggestions([]);
      }
    }, 250);

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [searchInput, selectedGroup]);

  const selectSuggestion = async (g) => {
    setSuggestions([]);
    setSearchInput(g.name);
    setSelectedGroup(null);
    setJoinMessage('');
    try {
      const res = await axios.get(`/api/community_groups/${g.id}`, { withCredentials: true });
      setSelectedGroup(res.data);
    } catch (e) {
      setSelectedGroup(null);
    }
  };

  const requestToJoin = async () => {
    if (!selectedGroup?.id) return;
    setRequestingJoin(true);
    try {
      await axios.post(
        `/api/community_groups/${selectedGroup.id}/request_to_join`,
        { message: joinMessage || null },
        { withCredentials: true }
      );
      await loadAll();
      setActiveTab('requested');
    } finally {
      setRequestingJoin(false);
    }
  };

  const leaveGroup = async (group) => {
    if (group.sole_admin) {
      window.alert("You are the only admin of this group. Assign another admin before leaving.");
      return;
    }

    const warning = group.public === false
      ? "You've chosen to leave a private group. You won't be able to join back into this group unless the group admin explicitly invites you. Are you sure?"
      : "Leave this group?";

    if (!window.confirm(warning)) return;

    try {
      await axios.delete(`/api/my_groups/memberships/${group.membership_id}`, { withCredentials: true });
      await loadAll();
    } catch (e) {
      const message = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'Failed to leave group';
      window.alert(message);
    }
  };

  const updateSubGroup = async (group, subGroupId) => {
    setUpdatingSubGroupMembershipId(group.membership_id);
    try {
      const res = await axios.patch(
        `/api/my_groups/memberships/${group.membership_id}`,
        { sub_group_id: subGroupId },
        { withCredentials: true }
      );
      const updated = res.data?.sub_group || null;
      setCurrentGroups((prev) => prev.map((g) => (
        g.membership_id === group.membership_id ? { ...g, sub_group: updated } : g
      )));
      // Ensure Profile pages reflect latest membership/sub-group.
      await checkAuthStatus();
    } catch (e) {
      const message = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'Failed to update sub-group';
      window.alert(message);
    } finally {
      setUpdatingSubGroupMembershipId(null);
    }
  };

  const cancelRequest = async (requestId) => {
    if (!window.confirm('Delete this request?')) return;
    await axios.delete(`/api/my_groups/requests/${requestId}`, { withCredentials: true });
    await loadAll();
  };

  const acceptInvite = async (inviteId) => {
    await axios.post(`/api/my_groups/invites/${inviteId}/accept`, {}, { withCredentials: true });
    await loadAll();
    setActiveTab('current');
  };

  if (!currentUser) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-3xl">
        <div className="bg-white rounded-lg shadow-md p-6 text-center">
          <h2 className="text-2xl font-bold text-gray-900 mb-2">My Groups</h2>
          <p className="text-gray-600 mb-4">Please log in to view your groups.</p>
          <button
            onClick={() => setCurrentPage('login')}
            className="px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700"
          >
            Log In
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto py-8 px-4 max-w-5xl">
      <div className="mb-6 flex items-center justify-between">
        <div>
          <button
            onClick={() => setCurrentPage('profile')}
            className="text-emerald-600 hover:text-emerald-700"
          >
            ← Back to Profile
          </button>
          <h2 className="text-3xl font-bold text-gray-900 mt-2">My Groups</h2>
        </div>
      </div>

      {/* Public group search */}
      <div className="bg-white rounded-lg shadow-md p-6 mb-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-3">Find a public group to join</h3>
        <div className="relative">
          <input
            value={searchInput}
            onChange={(e) => {
              // If user edits after selecting a group, treat it as starting a new search.
              if (selectedGroup) {
                setSelectedGroup(null);
                setJoinMessage('');
              }
              setSearchInput(e.target.value);
            }}
            placeholder="Search by group name or short name..."
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
          />
          {!selectedGroup && suggestions.length > 0 && (
            <div className="absolute z-20 mt-1 w-full bg-white border border-gray-200 rounded-md shadow-lg max-h-64 overflow-auto">
              {suggestions.map((s) => (
                <button
                  key={s.id}
                  type="button"
                  onClick={() => selectSuggestion(s)}
                  className="w-full text-left px-4 py-3 hover:bg-gray-50"
                >
                  <div className="font-medium text-gray-900">{s.name}</div>
                  <div className="text-xs text-gray-500">
                    /g/{s.short_name} • {s.member_count} members • Created {new Date(s.created_at).toLocaleDateString()}
                  </div>
                </button>
              ))}
            </div>
          )}
        </div>

        {selectedGroup && (
          <div className="mt-5 border border-gray-200 rounded-lg p-4">
            <div className="flex items-start justify-between gap-4">
              <div>
                <div className="text-xl font-semibold text-gray-900">{selectedGroup.name}</div>
                <div className="text-sm text-gray-600">
                  /g/{selectedGroup.short_name} • {selectedGroup.member_count} members • Created {new Date(selectedGroup.created_at).toLocaleDateString()}
                </div>
              </div>
              <div className="flex items-center gap-3">
                <button
                  onClick={() => {
                    setSelectedGroup(null);
                    setJoinMessage('');
                    setSearchInput('');
                    setSuggestions([]);
                  }}
                  className="text-gray-600 hover:text-gray-800 underline text-sm"
                >
                  Change selection
                </button>
                <button
                  onClick={() => setCurrentPage('groupPage', { groupShortName: selectedGroup.short_name })}
                  className="text-emerald-700 hover:text-emerald-800 underline text-sm"
                >
                  View group page
                </button>
              </div>
            </div>

            <div className="mt-4 grid grid-cols-1 md:grid-cols-3 gap-3 items-end">
              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Message (optional)
                </label>
                <input
                  value={joinMessage}
                  onChange={(e) => setJoinMessage(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md"
                  placeholder="Add a note for the admins..."
                />
              </div>
              <div className="md:col-span-1">
                <button
                  onClick={requestToJoin}
                  disabled={requestingJoin || ['member', 'requested'].includes(selectedGroup.membership_state)}
                  className="w-full px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {selectedGroup.membership_state === 'member'
                    ? 'Already a member'
                    : selectedGroup.membership_state === 'requested'
                      ? 'Request sent'
                      : requestingJoin ? 'Requesting...' : 'Request to join'}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Tabs */}
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="border-b mb-6">
          <nav className="-mb-px flex gap-6">
            {TABS.map((t) => (
              <button
                key={t.key}
                onClick={() => setActiveTab(t.key)}
                className={`py-2 border-b-2 text-sm font-medium ${
                  activeTab === t.key
                    ? 'border-emerald-600 text-emerald-700'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                {t.label} ({counts[t.key]})
              </button>
            ))}
          </nav>
        </div>

        {loading ? (
          <div className="text-gray-600">Loading...</div>
        ) : (
          <>
            {activeTab === 'current' && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {currentGroups.map((g) => (
                  <div key={g.membership_id} className="border border-gray-200 rounded-lg p-4">
                    <div className="flex items-start justify-between gap-4">
                      <div>
                        <div className="text-lg font-semibold text-gray-900">
                          {g.sub_group ? `${g.name} — ${g.sub_group.name}` : g.name}
                        </div>
                        <div className="text-sm text-gray-600">/g/{g.short_name}</div>
                        <div className="text-xs text-gray-500 mt-1">
                          Joined {new Date(g.joined_at).toLocaleDateString()}
                        </div>

                        {g.sub_groups && g.sub_groups.length > 0 && (
                          <div className="mt-3">
                            <label className="block text-xs font-medium text-gray-600 mb-1">
                              Sub Group
                            </label>
                            <select
                              className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
                              value={g.sub_group?.id || ''}
                              disabled={updatingSubGroupMembershipId === g.membership_id}
                              onChange={(e) => {
                                const value = e.target.value ? parseInt(e.target.value, 10) : null;
                                updateSubGroup(g, value);
                              }}
                            >
                              <option value="">None</option>
                              {g.sub_groups.map((sg) => (
                                <option key={sg.id} value={sg.id}>{sg.name}</option>
                              ))}
                            </select>
                          </div>
                        )}
                      </div>
                      <button
                        onClick={() => setCurrentPage('groupPage', { groupShortName: g.short_name })}
                        className="text-emerald-700 hover:text-emerald-800 underline text-sm"
                      >
                        View
                      </button>
                    </div>
                    <div className="mt-4 flex justify-between items-center">
                      <span
                        className="inline-block"
                        title={g.sole_admin ? 'You are the only admin of this group. Assign another admin before leaving.' : ''}
                      >
                        <button
                          onClick={() => leaveGroup(g)}
                          disabled={g.sole_admin}
                          className={`text-sm underline ${
                            g.sole_admin
                              ? 'text-gray-400 cursor-not-allowed'
                              : 'text-red-700 hover:text-red-800'
                          }`}
                        >
                          Leave this group
                        </button>
                      </span>
                    </div>
                  </div>
                ))}
                {currentGroups.length === 0 && (
                  <p className="text-gray-600 text-sm">You aren’t a member of any groups yet.</p>
                )}
              </div>
            )}

            {activeTab === 'requested' && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {requested.map((r) => (
                  <div key={r.id} className="border border-gray-200 rounded-lg p-4">
                    <div className="flex items-start justify-between gap-4">
                      <div>
                        <div className="text-lg font-semibold text-gray-900">{r.community_group?.name}</div>
                        <div className="text-sm text-gray-600">/g/{r.community_group?.short_name}</div>
                        <div className="text-xs text-gray-500 mt-1">
                          Requested {new Date(r.created_at).toLocaleDateString()}
                        </div>
                        {r.message && (
                          <div className="text-sm text-gray-700 mt-2">
                            <span className="font-medium">Message:</span> {r.message}
                          </div>
                        )}
                      </div>
                      <button
                        onClick={() => setCurrentPage('groupPage', { groupShortName: r.community_group?.short_name })}
                        className="text-emerald-700 hover:text-emerald-800 underline text-sm"
                      >
                        View
                      </button>
                    </div>
                    <div className="mt-4 flex justify-end">
                      <button
                        onClick={() => cancelRequest(r.id)}
                        className="text-red-700 hover:text-red-800 text-sm underline"
                      >
                        Delete request
                      </button>
                    </div>
                  </div>
                ))}
                {requested.length === 0 && (
                  <p className="text-gray-600 text-sm">No pending join requests.</p>
                )}
              </div>
            )}

            {activeTab === 'invites' && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {invites.map((inv) => (
                  <div key={inv.id} className="border border-gray-200 rounded-lg p-4">
                    <div className="flex items-start justify-between gap-4">
                      <div>
                        <div className="text-lg font-semibold text-gray-900">{inv.community_group?.name}</div>
                        <div className="text-sm text-gray-600">/g/{inv.community_group?.short_name}</div>
                        <div className="text-xs text-gray-500 mt-1">
                          Invited {new Date(inv.created_at).toLocaleDateString()}
                          {inv.inviter?.display_name ? ` by ${inv.inviter.display_name}` : ''}
                        </div>
                        {inv.message && (
                          <div className="text-sm text-gray-700 mt-2">
                            <span className="font-medium">Message:</span> {inv.message}
                          </div>
                        )}
                      </div>
                      <button
                        onClick={() => setCurrentPage('groupPage', { groupShortName: inv.community_group?.short_name })}
                        className="text-emerald-700 hover:text-emerald-800 underline text-sm"
                      >
                        View
                      </button>
                    </div>
                    <div className="mt-4 flex justify-end">
                      <button
                        onClick={() => acceptInvite(inv.id)}
                        className="px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700 text-sm"
                      >
                        Accept
                      </button>
                    </div>
                  </div>
                ))}
                {invites.length === 0 && (
                  <p className="text-gray-600 text-sm">No pending invites.</p>
                )}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
};

export default MyGroups;


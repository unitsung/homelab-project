package com.homelab.app.data.repository

import junit.framework.TestCase.assertFalse
import junit.framework.TestCase.assertTrue
import org.junit.Test

class TrueNasRepositoryTest {
    @Test
    fun `secure transport accepts https and wss only`() {
        assertTrue(TrueNasRepository.usesSecureApiTransport("https://truenas.local"))
        assertTrue(TrueNasRepository.usesSecureApiTransport("wss://truenas.local/api/current"))
        assertTrue(TrueNasRepository.usesSecureApiTransport("truenas.local"))
        assertFalse(TrueNasRepository.usesSecureApiTransport("http://truenas.local"))
        assertFalse(TrueNasRepository.usesSecureApiTransport("ws://truenas.local/websocket"))
    }
}

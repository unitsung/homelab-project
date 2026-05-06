package com.homelab.app.domain.model

import com.homelab.app.util.ServiceType
import junit.framework.TestCase.assertEquals
import junit.framework.TestCase.assertNull
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Test

class ServiceConnectionTest {
    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        isLenient = true
    }

    @Test
    fun `serializes service instance fields`() {
        val instance = ServiceInstance(
            id = "instance-1",
            type = ServiceType.PIHOLE,
            label = "Pi-hole Home",
            url = "https://pihole.local",
            token = "sid123",
            piholePassword = "secret",
            piholeAuthMode = PiHoleAuthMode.SESSION,
            fallbackUrl = "https://pihole.example.com"
        )

        val encoded = json.encodeToString(instance)
        val decoded = json.decodeFromString<ServiceInstance>(encoded)

        assertEquals("instance-1", decoded.id)
        assertEquals("Pi-hole Home", decoded.label)
        assertEquals("sid123", decoded.token)
        assertEquals("secret", decoded.piHoleStoredSecret)
        assertEquals(PiHoleAuthMode.SESSION, decoded.piholeAuthMode)
        assertEquals("https://pihole.example.com", decoded.fallbackUrl)
    }

    @Test
    fun `old pihole payload falls back to apiKey secret`() {
        val payload = """
            {
              "type": "PIHOLE",
              "url": "https://pihole.local",
              "token": "legacy-token",
              "apiKey": "legacy-secret"
            }
        """.trimIndent()

        val decoded = json.decodeFromString<ServiceConnection>(payload)

        assertEquals(ServiceType.PIHOLE, decoded.type)
        assertEquals("legacy-secret", decoded.piHoleStoredSecret)
        assertNull(decoded.piholePassword)
        assertNull(decoded.piholeAuthMode)
    }

    @Test
    fun `legacy connection migrates with display name label`() {
        val legacy = ServiceConnection(
            type = ServiceType.BESZEL,
            url = "https://beszel.local",
            token = "token-1",
            username = "ops@example.com"
        )

        val migrated = legacy.migratedInstance("instance-2")

        assertEquals("instance-2", migrated.id)
        assertEquals(ServiceType.BESZEL, migrated.type)
        assertEquals(ServiceType.BESZEL.displayName, migrated.label)
        assertEquals("ops@example.com", migrated.username)
    }

    @Test
    fun `stored truenas variants resolve to one service type`() {
        assertEquals(ServiceType.TRUENAS, ServiceType.fromStoredName("TRUENAS"))
        assertEquals(ServiceType.TRUENAS, ServiceType.fromStoredName("truenas-scale"))
        assertEquals(ServiceType.TRUENAS, ServiceType.fromStoredName("truenas_core"))
    }
}

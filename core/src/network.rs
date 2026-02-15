use std::{
    net::{IpAddr, Ipv4Addr, SocketAddr, UdpSocket},
    time::{Duration, SystemTime},
};

use bevy::{prelude::*, time::common_conditions::*};
use bevy_replicon::{prelude::*, server};
use bevy_replicon_renet::{
    RenetChannelsExt, RenetClient, RenetServer,
    netcode::{
        ClientAuthentication, NetcodeClientTransport, NetcodeServerTransport, ServerAuthentication,
        ServerConfig,
    },
    renet::ConnectionConfig,
};

use crate::error_event::trigger_error;

pub(super) fn plugin(app: &mut App) {
    app.add_observer(host.pipe(trigger_error))
        .add_observer(stop_server)
        .add_observer(connect.pipe(trigger_error))
        .add_observer(disconnect)
        .add_systems(
            PostUpdate,
            server::increment_tick.run_if(on_real_timer(Duration::from_secs_f32(0.1))),
        );
}

pub const DEFAULT_PORT: u16 = 4761;
const PROTOCOL_ID: u64 = 8;

fn host(host: On<Host>, mut commands: Commands, channels: Res<RepliconChannels>) -> Result<()> {
    info!("hosting on port {}", host.port);

    let current_time = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH)?;
    let public_addr = SocketAddr::new(Ipv4Addr::LOCALHOST.into(), host.port);
    let socket = UdpSocket::bind(public_addr)?;
    let server_config = ServerConfig {
        current_time,
        max_clients: 1,
        protocol_id: PROTOCOL_ID,
        authentication: ServerAuthentication::Unsecure,
        public_addresses: vec![public_addr],
    };
    let transport = NetcodeServerTransport::new(server_config, socket)?;

    let server = RenetServer::new(ConnectionConfig {
        server_channels_config: channels.server_configs(),
        client_channels_config: channels.client_configs(),
        ..Default::default()
    });

    commands.insert_resource(transport);
    commands.insert_resource(server);

    Ok(())
}

fn stop_server(_on: On<StopServer>, mut commands: Commands, mut server: ResMut<RenetServer>) {
    info!("stopping server");
    server.disconnect_all();
    commands.remove_resource::<RenetServer>();
    commands.remove_resource::<NetcodeServerTransport>();
}

fn connect(
    connect: On<Connect>,
    mut commands: Commands,
    channels: Res<RepliconChannels>,
) -> Result<()> {
    info!("connecting to {}:{}", connect.ip, connect.port);

    let current_time = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH)?;
    let client_id = current_time.as_millis() as u64;
    let server_addr = SocketAddr::new(connect.ip, connect.port);
    let socket = UdpSocket::bind((connect.ip, 0))?;
    let authentication = ClientAuthentication::Unsecure {
        client_id,
        protocol_id: PROTOCOL_ID,
        server_addr,
        user_data: None,
    };
    let transport = NetcodeClientTransport::new(current_time, authentication, socket)?;

    let client = RenetClient::new(ConnectionConfig {
        server_channels_config: channels.server_configs(),
        client_channels_config: channels.client_configs(),
        ..Default::default()
    });

    commands.insert_resource(transport);
    commands.insert_resource(client);

    Ok(())
}

fn disconnect(
    _on: On<Disconnect>,
    mut commands: Commands,
    mut transport: ResMut<NetcodeClientTransport>,
) {
    info!("disconnecting");
    transport.disconnect();
    commands.remove_resource::<NetcodeClientTransport>();
    commands.remove_resource::<RenetClient>();
}

#[derive(Event)]
pub struct Host {
    pub port: u16,
}

#[derive(Event)]
pub struct StopServer;

#[derive(Event)]
pub struct Connect {
    pub ip: IpAddr,
    pub port: u16,
}

#[derive(Event)]
pub struct Disconnect;

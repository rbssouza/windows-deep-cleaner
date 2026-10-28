<#
.SYNOPSIS
    Enterprise Cleaner v6.4.3 - Versao Script (.ps1) Blindada
.DESCRIPTION
    - Protecao contra Junction Points (Links Simbolicos)
    - Protecao contra Path Hijacking (Caminhos absolutos do sistema)
    - Blacklist de perfis de servico (SQL, IIS, etc)
    - Animacao de DISM em background
    - UI: Central de Limpeza e Menu Principal
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# Esconde o console (se houver)
try {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W32 {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
    $h = [W32]::GetConsoleWindow()
    if ($h -ne [IntPtr]::Zero) { [W32]::ShowWindow($h, 0) | Out-Null }
} catch { }

$Global:Espaco = 0
$Global:Itens  = 0
$Global:Ultima = "-"
$Global:EmUso  = $false
$Global:LogPath = "$env:TEMP\EnterpriseCleaner_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$Global:ErrorLog = "$env:USERPROFILE\Desktop\EnterpriseCleaner_ERRO.txt"
$Global:PendingTipo = $null

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Enterprise Cleaner" Height="750" Width="1200"
        MinHeight="650" MinWidth="1000"
        WindowStartupLocation="CenterScreen" WindowStyle="None"
        AllowsTransparency="True" Background="Transparent" ResizeMode="CanResize">
    <Window.Resources>
        <Style x:Key="NavBtn" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#a4b0d0"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Height" Value="46"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="8" Margin="0,2">
                            <Grid>
                                <Border x:Name="ind" Width="4" HorizontalAlignment="Left" Background="Transparent" CornerRadius="2,0,0,2"/>
                                <ContentPresenter Margin="20,0,10,0" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#151a35"/>
                                <Setter Property="Foreground" Value="#ffffff"/>
                            </Trigger>
                            <Trigger Property="Tag" Value="active">
                                <Setter TargetName="bd" Property="Background" Value="#151a35"/>
                                <Setter TargetName="ind" Property="Background" Value="#00e5ff"/>
                                <Setter Property="Foreground" Value="#00e5ff"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="PrimaryBtn" TargetType="Button">
            <Setter Property="Foreground" Value="#080b1a"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Height" Value="46"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" CornerRadius="8" Background="#00e5ff">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#00ff88"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="DangerBtn" TargetType="Button">
            <Setter Property="Foreground" Value="#ffffff"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Height" Value="42"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" CornerRadius="8" Background="#ff3366">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#ff6b6b"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="SecondaryBtn" TargetType="Button">
            <Setter Property="Foreground" Value="#a4b0d0"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Height" Value="42"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#1e2a5e"/>
            <Setter Property="Background" Value="#11152b"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" CornerRadius="8"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#1a1f3a"/>
                                <Setter Property="Foreground" Value="#00e5ff"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ActionCard" TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="#11152b" CornerRadius="12"
                                BorderBrush="#1e2a5e" BorderThickness="1" Padding="22">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#151a35"/>
                                <Setter TargetName="bd" Property="BorderBrush" Value="#00e5ff"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="TechProgress" TargetType="ProgressBar">
            <Setter Property="Height" Value="14"/>
            <Setter Property="Background" Value="#11152b"/>
            <Setter Property="Foreground" Value="#00e5ff"/>
            <Setter Property="BorderThickness" Value="0"/>
        </Style>
    </Window.Resources>

    <Border CornerRadius="12" BorderBrush="#1e2a5e" BorderThickness="1" Background="#0a0e27">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="58"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <Border Grid.Row="0" Name="titleBar" Background="#070a20" CornerRadius="12,12,0,0">
                <Grid>
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="22,0,0,0">
                        <TextBlock Text="*" Foreground="#00e5ff" FontSize="22" VerticalAlignment="Center" Margin="0,0,12,0"/>
                        <TextBlock Text="ENTERPRISE" Foreground="#ffffff" FontSize="15" FontWeight="Black" VerticalAlignment="Center"/>
                        <TextBlock Text=" CLEANER" Foreground="#00e5ff" FontSize="15" FontWeight="Black" VerticalAlignment="Center"/>
                        <Border Background="#1a1f3a" CornerRadius="4" Padding="8,3" Margin="15,0,0,0">
                            <TextBlock Text="v6.4.3" Foreground="#00e5ff" FontSize="10" FontWeight="Bold"/>
                        </Border>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,0,8,0">
                        <Button Name="btnMin" Content="-" Width="45" Height="38" Background="Transparent" Foreground="#a4b0d0" BorderThickness="0" FontSize="16" Cursor="Hand"/>
                        <Button Name="btnMax" Content="[]" Width="45" Height="38" Background="Transparent" Foreground="#a4b0d0" BorderThickness="0" FontSize="12" Cursor="Hand"/>
                        <Button Name="btnClose" Content="X" Width="45" Height="38" Background="Transparent" Foreground="#a4b0d0" BorderThickness="0" FontSize="14" Cursor="Hand"/>
                    </StackPanel>
                </Grid>
            </Border>

            <Grid Grid.Row="1">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="240"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <Border Grid.Column="0" Background="#050813" CornerRadius="0,0,0,12" Padding="12">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <StackPanel Grid.Row="0" Margin="8,18,8,15">
                            <TextBlock Text="SISTEMA" Foreground="#4a5680" FontSize="10" FontWeight="Bold"/>
                            <TextBlock Text="Pronto para limpar" Foreground="#ffffff" FontSize="12" Margin="0,4,0,0"/>
                        </StackPanel>

                        <Border Grid.Row="1" Height="1" Background="#1e2a5e" Margin="8,0,8,15"/>

                        <StackPanel Grid.Row="2">
                            <TextBlock Text="NAVEGACAO" Foreground="#4a5680" FontSize="10" FontWeight="Bold" Margin="10,0,0,10"/>
                            <Button Name="btnDash"   Style="{StaticResource NavBtn}" Content="  Central de Limpeza" Tag="active"/>
                            <Button Name="btnQuick"  Style="{StaticResource NavBtn}" Content="  Limpeza Rapida"/>
                            <Button Name="btnPadrao" Style="{StaticResource NavBtn}" Content="  Limpeza Padrao"/>
                            <Button Name="btnDeep"   Style="{StaticResource NavBtn}" Content="  Limpeza Profunda"/>
                            <Button Name="btnPerfis" Style="{StaticResource NavBtn}" Content="  Gerenciar Perfis"/>
                            <Button Name="btnCustom" Style="{StaticResource NavBtn}" Content="  Personalizada"/>
                        </StackPanel>

                        <Border Grid.Row="3" Background="#11152b" CornerRadius="8" Padding="14" Margin="6,15,6,6">
                            <StackPanel>
                                <TextBlock Text="STATUS" Foreground="#4a5680" FontSize="10" FontWeight="Bold"/>
                                <StackPanel Orientation="Horizontal" Margin="0,6,0,0">
                                    <Ellipse Width="8" Height="8" Fill="#00ff88" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                    <TextBlock Text="Sistema OK" Foreground="#00ff88" FontSize="12" FontWeight="Bold"/>
                                </StackPanel>
                            </StackPanel>
                        </Border>
                    </Grid>
                </Border>

                <Grid Grid.Column="1">
                    <Grid Name="viewDash" Margin="35,30,35,30">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <StackPanel Grid.Row="0" Margin="0,0,0,25">
                            <TextBlock Text="Bem-vindo ao" Foreground="#6b7280" FontSize="14"/>
                            <TextBlock Text="Enterprise Cleaner" Foreground="#ffffff" FontSize="30" FontWeight="Black" Margin="0,3,0,6"/>
                            <TextBlock Text="Sistema profissional de limpeza profunda e segura" Foreground="#00e5ff" FontSize="13"/>
                        </StackPanel>

                        <Grid Grid.Row="1" Margin="0,0,0,25">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="15"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="15"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <Border Grid.Column="0" Background="#11152b" CornerRadius="12" BorderBrush="#1e2a5e" BorderThickness="1" Padding="22">
                                <StackPanel>
                                    <TextBlock Text="ESPACO LIBERADO" Foreground="#6b7280" FontSize="10" FontWeight="Bold"/>
                                    <TextBlock Name="lblSpaceVal" Text="0 MB" Foreground="#00ff88" FontSize="26" FontWeight="Black" Margin="0,8,0,0"/>
                                    <TextBlock Text="nesta sessao" Foreground="#4a5680" FontSize="11" Margin="0,4,0,0"/>
                                </StackPanel>
                            </Border>

                            <Border Grid.Column="2" Background="#11152b" CornerRadius="12" BorderBrush="#1e2a5e" BorderThickness="1" Padding="22">
                                <StackPanel>
                                    <TextBlock Text="ARQUIVOS REMOVIDOS" Foreground="#6b7280" FontSize="10" FontWeight="Bold"/>
                                    <TextBlock Name="lblFilesVal" Text="0" Foreground="#00e5ff" FontSize="26" FontWeight="Black" Margin="0,8,0,0"/>
                                    <TextBlock Text="nesta sessao" Foreground="#4a5680" FontSize="11" Margin="0,4,0,0"/>
                                </StackPanel>
                            </Border>

                            <Border Grid.Column="4" Background="#11152b" CornerRadius="12" BorderBrush="#1e2a5e" BorderThickness="1" Padding="22">
                                <StackPanel>
                                    <TextBlock Text="ULTIMA LIMPEZA" Foreground="#6b7280" FontSize="10" FontWeight="Bold"/>
                                    <TextBlock Name="lblLastVal" Text="-" Foreground="#7c3aed" FontSize="18" FontWeight="Black" Margin="0,12,0,0"/>
                                    <TextBlock Text="nesta maquina" Foreground="#4a5680" FontSize="11" Margin="0,4,0,0"/>
                                </StackPanel>
                            </Border>
                        </Grid>

                        <Grid Grid.Row="2" Margin="0,0,0,20">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="15"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="15"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <Button Grid.Column="0" Name="cardQuick" Style="{StaticResource ActionCard}">
                                <StackPanel>
                                    <TextBlock Text=">>" Foreground="#00ff88" FontSize="26" FontWeight="Black" Margin="0,0,0,12"/>
                                    <TextBlock Text="LIMPEZA RAPIDA" Foreground="#ffffff" FontSize="15" FontWeight="Bold"/>
                                    <TextBlock Text="Temporarios do sistema e usuarios" Foreground="#6b7280" FontSize="12" TextWrapping="Wrap" Margin="0,8,0,0"/>
                                    <Border Height="4" Width="40" Background="#00ff88" CornerRadius="2" HorizontalAlignment="Left" Margin="0,15,0,0"/>
                                </StackPanel>
                            </Button>

                            <Button Grid.Column="2" Name="cardPadrao" Style="{StaticResource ActionCard}">
                                <StackPanel>
                                    <TextBlock Text="**" Foreground="#00e5ff" FontSize="26" FontWeight="Black" Margin="0,0,0,12"/>
                                    <TextBlock Text="LIMPEZA PADRAO" Foreground="#ffffff" FontSize="15" FontWeight="Bold"/>
                                    <TextBlock Text="Rapida + caches + logs + lixeira" Foreground="#6b7280" FontSize="12" TextWrapping="Wrap" Margin="0,8,0,0"/>
                                    <Border Height="4" Width="40" Background="#00e5ff" CornerRadius="2" HorizontalAlignment="Left" Margin="0,15,0,0"/>
                                </StackPanel>
                            </Button>

                            <Button Grid.Column="4" Name="cardDeep" Style="{StaticResource ActionCard}">
                                <StackPanel>
                                    <TextBlock Text="!!" Foreground="#ff3366" FontSize="26" FontWeight="Black" Margin="0,0,0,12"/>
                                    <TextBlock Text="LIMPEZA PROFUNDA" Foreground="#ffffff" FontSize="15" FontWeight="Bold"/>
                                    <TextBlock Text="Padrao + Windows Update + DISM" Foreground="#6b7280" FontSize="12" TextWrapping="Wrap" Margin="0,8,0,0"/>
                                    <Border Height="4" Width="40" Background="#ff3366" CornerRadius="2" HorizontalAlignment="Left" Margin="0,15,0,0"/>
                                </StackPanel>
                            </Button>
                        </Grid>

                        <Border Grid.Row="3" Background="#0d1233" CornerRadius="10" Padding="18" BorderBrush="#1e2a5e" BorderThickness="1">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="i" Foreground="#00e5ff" FontSize="18" FontWeight="Black" VerticalAlignment="Center" Margin="0,0,15,0"/>
                                <TextBlock Text="Todos os modulos executam verificacoes de seguranca e criam ponto de restauracao automaticamente." Foreground="#a4b0d0" FontSize="12" VerticalAlignment="Center" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>
                    </Grid>

                    <Grid Name="viewConfirm" Margin="35,30,35,30" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <StackPanel Grid.Row="0" Margin="0,0,0,12">
                            <TextBlock Text="Confirmar operacao" Foreground="#6b7280" FontSize="13"/>
                            <TextBlock Name="lblConfirmTitle" Text="Limpeza" Foreground="#ffffff" FontSize="28" FontWeight="Black" Margin="0,3,0,0"/>
                        </StackPanel>

                        <TextBlock Grid.Row="1" Name="lblConfirmDesc" Text="" Foreground="#a4b0d0" FontSize="13" TextWrapping="Wrap" Margin="0,0,0,15"/>

                        <Border Grid.Row="2" Background="#0d1233" CornerRadius="10" Padding="16" BorderBrush="#1e2a5e" BorderThickness="1" Margin="0,0,0,15">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="i" Foreground="#00e5ff" FontSize="18" FontWeight="Black" VerticalAlignment="Center" Margin="0,0,15,0"/>
                                <TextBlock Text="Um ponto de restauracao do sistema sera criado automaticamente antes de iniciar." Foreground="#a4b0d0" FontSize="12" VerticalAlignment="Center" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>

                        <Border Grid.Row="3" Background="#11152b" CornerRadius="12" BorderBrush="#1e2a5e" BorderThickness="1" Padding="15">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <TextBlock Grid.Row="0" Text="MODULOS QUE SERAO EXECUTADOS" Foreground="#6b7280" FontSize="10" FontWeight="Bold" Margin="0,0,0,10"/>
                                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                                    <StackPanel Name="stackConfirm"/>
                                </ScrollViewer>
                            </Grid>
                        </Border>

                        <Grid Grid.Row="4" Margin="0,18,0,0">
                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
                                <Button Name="btnCancelarLimpeza" Content="CANCELAR" Style="{StaticResource SecondaryBtn}" Width="160"/>
                            </StackPanel>
                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                                <Button Name="btnIniciarLimpeza" Content="INICIAR LIMPEZA" Style="{StaticResource PrimaryBtn}" Width="240"/>
                            </StackPanel>
                        </Grid>
                    </Grid>

                    <Grid Name="viewProgress" Margin="35,30,35,30" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <StackPanel Grid.Row="0" Margin="0,0,0,20">
                            <TextBlock Name="lblOpTitle" Text="Executando..." Foreground="#ffffff" FontSize="24" FontWeight="Black"/>
                            <TextBlock Name="lblOpDetail" Text="Preparando..." Foreground="#00e5ff" FontSize="13" Margin="0,8,0,0"/>
                        </StackPanel>

                        <Border Grid.Row="1" Background="#11152b" CornerRadius="12" BorderBrush="#1e2a5e" BorderThickness="1" Padding="25" Margin="0,0,0,18">
                            <StackPanel>
                                <Grid Margin="0,0,0,10">
                                    <TextBlock Text="PROGRESSO" Foreground="#6b7280" FontSize="10" FontWeight="Bold"/>
                                    <TextBlock Name="lblPercent" Text="0%" Foreground="#00e5ff" FontSize="12" FontWeight="Bold" HorizontalAlignment="Right"/>
                                </Grid>
                                <ProgressBar Name="pbProgress" Style="{StaticResource TechProgress}" Value="0" Maximum="100"/>
                            </StackPanel>
                        </Border>

                        <Border Grid.Row="2" Background="#050813" CornerRadius="12" BorderBrush="#1e2a5e" BorderThickness="1" Padding="15">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <TextBlock Grid.Row="0" Text="LOG" Foreground="#6b7280" FontSize="10" FontWeight="Bold" Margin="0,0,0,10"/>
                                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Name="logScroll">
                                    <TextBlock Name="txtLog" Foreground="#00ff88" FontFamily="Consolas" FontSize="11" TextWrapping="Wrap"/>
                                </ScrollViewer>
                            </Grid>
                        </Border>

                        <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,0">
                            <Button Name="btnVoltarDash" Content="VOLTAR AO MENU PRINCIPAL" Style="{StaticResource SecondaryBtn}" Width="250"/>
                        </StackPanel>
                    </Grid>

                    <Grid Name="viewPerfis" Margin="35,30,35,30" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <StackPanel Grid.Row="0" Margin="0,0,0,18">
                            <TextBlock Text="Gerenciador de Perfis" Foreground="#ffffff" FontSize="26" FontWeight="Black"/>
                            <TextBlock Text="Selecione os perfis que deseja remover (pasta + registro)" Foreground="#6b7280" FontSize="12" Margin="0,5,0,0"/>
                        </StackPanel>

                        <Border Grid.Row="1" Background="#2a1a1f" CornerRadius="10" BorderBrush="#ff3366" BorderThickness="1" Padding="15" Margin="0,0,0,15">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="!" Foreground="#ff3366" FontSize="20" FontWeight="Black" VerticalAlignment="Center" Margin="0,0,12,0"/>
                                <TextBlock Text="ACAO IRREVERSIVEL: arquivos, documentos e configuracoes do perfil serao permanentemente removidos." Foreground="#ff6b6b" FontSize="12" VerticalAlignment="Center" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>

                        <Border Grid.Row="2" Background="#11152b" CornerRadius="12" BorderBrush="#1e2a5e" BorderThickness="1" Padding="15">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>

                                <Grid Grid.Row="0" Margin="5,0,5,12">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="40"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="120"/>
                                        <ColumnDefinition Width="130"/>
                                        <ColumnDefinition Width="110"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="1" Text="USUARIO" Foreground="#6b7280" FontSize="10" FontWeight="Bold"/>
                                    <TextBlock Grid.Column="2" Text="TAMANHO" Foreground="#6b7280" FontSize="10" FontWeight="Bold"/>
                                    <TextBlock Grid.Column="3" Text="ULTIMO USO" Foreground="#6b7280" FontSize="10" FontWeight="Bold"/>
                                    <TextBlock Grid.Column="4" Text="STATUS" Foreground="#6b7280" FontSize="10" FontWeight="Bold"/>
                                </Grid>

                                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                                    <StackPanel Name="stackPerfis"/>
                                </ScrollViewer>
                            </Grid>
                        </Border>

                        <Grid Grid.Row="3" Margin="0,18,0,0">
                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
                                <Button Name="btnSelAll" Content="SELECIONAR TODOS" Style="{StaticResource SecondaryBtn}" Width="170" Margin="0,0,10,0"/>
                                <Button Name="btnSelNone" Content="LIMPAR SELECAO" Style="{StaticResource SecondaryBtn}" Width="160"/>
                            </StackPanel>
                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                                <Button Name="btnRefreshPerfis" Content="ATUALIZAR" Style="{StaticResource SecondaryBtn}" Width="130" Margin="0,0,10,0"/>
                                <Button Name="btnRemoverPerfis" Content="REMOVER SELECIONADOS" Style="{StaticResource DangerBtn}" Width="230"/>
                            </StackPanel>
                        </Grid>
                    </Grid>

                    <Grid Name="viewCustom" Margin="35,30,35,30" Visibility="Collapsed">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <StackPanel Grid.Row="0" Margin="0,0,0,18">
                            <TextBlock Text="Limpeza Personalizada" Foreground="#ffffff" FontSize="26" FontWeight="Black"/>
                            <TextBlock Text="Marque os modulos que deseja executar" Foreground="#6b7280" FontSize="12" Margin="0,5,0,0"/>
                        </StackPanel>

                        <Border Grid.Row="1" Background="#11152b" CornerRadius="12" BorderBrush="#1e2a5e" BorderThickness="1" Padding="20">
                            <ScrollViewer VerticalScrollBarVisibility="Auto">
                                <StackPanel Name="stackCustom"/>
                            </ScrollViewer>
                        </Border>

                        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,0">
                            <Button Name="btnExecCustom" Content="EXECUTAR SELECIONADOS" Style="{StaticResource PrimaryBtn}" Width="280"/>
                        </StackPanel>
                    </Grid>
                </Grid>
            </Grid>
        </Grid>
    </Border>
</Window>
'@

try {
    [xml]$xmlDoc = $xaml
    $reader = New-Object System.Xml.XmlNodeReader $xmlDoc
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    [System.IO.File]::WriteAllText($Global:ErrorLog, "ERRO XAML: $($_.Exception.Message)", [System.Text.Encoding]::UTF8)
    [System.Windows.MessageBox]::Show("Erro ao carregar interface. Detalhes: $Global:ErrorLog", "Erro", "OK", "Error") | Out-Null
    Exit 1
}

$c = @{}
$nomes = @(
    "titleBar","btnMin","btnMax","btnClose",
    "btnDash","btnQuick","btnPadrao","btnDeep","btnPerfis","btnCustom",
    "viewDash","viewConfirm","viewProgress","viewPerfis","viewCustom",
    "lblSpaceVal","lblFilesVal","lblLastVal",
    "cardQuick","cardPadrao","cardDeep",
    "lblConfirmTitle","lblConfirmDesc","stackConfirm","btnIniciarLimpeza","btnCancelarLimpeza",
    "lblOpTitle","lblOpDetail","lblPercent","pbProgress","logScroll","txtLog","btnVoltarDash",
    "stackPerfis","btnSelAll","btnSelNone","btnRefreshPerfis","btnRemoverPerfis",
    "stackCustom","btnExecCustom"
)
foreach ($n in $nomes) {
    $ctrl = $window.FindName($n)
    if ($ctrl) { $c[$n] = $ctrl }
}

function Get-Tam { param($P) try { $t = (Get-ChildItem $P -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum -EA SilentlyContinue).Sum; if ($null -eq $t) { return 0 }; return $t } catch { 0 } }
function Fmt { param([double]$B) if ($B -ge 1GB) { "{0:N2} GB" -f ($B/1GB) } elseif ($B -ge 1MB) { "{0:N2} MB" -f ($B/1MB) } elseif ($B -ge 1KB) { "{0:N2} KB" -f ($B/1KB) } else { "$([int]$B) B" } }
function DoEvents { try { $window.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background) } catch { } }

function Log {
    param($T, $N = "info")
    $p = @{ info="[..]"; ok="[OK]"; err="[!!]"; skip="[--]" }
    if ($c.txtLog) { $c.txtLog.Text += "$($p[$N]) $T`n"; if ($c.logScroll) { $c.logScroll.ScrollToEnd() } }
    Add-Content -Path $Global:LogPath -Value "[$(Get-Date -Format 'HH:mm:ss')] [$N] $T" -EA SilentlyContinue
    DoEvents
}

function Set-Prog {
    param($Pct, $Det = "")
    if ($c.pbProgress) { $c.pbProgress.Value = $Pct }
    if ($c.lblPercent) { $c.lblPercent.Text = "$Pct%" }
    if ($Det -and $c.lblOpDetail) { $c.lblOpDetail.Text = $Det }
    DoEvents
}

function Upd-Stats {
    if ($c.lblSpaceVal) { $c.lblSpaceVal.Text = Fmt $Global:Espaco }
    if ($c.lblFilesVal) { $c.lblFilesVal.Text = "$($Global:Itens)" }
    if ($c.lblLastVal)  { $c.lblLastVal.Text  = $Global:Ultima }
}

function Show-View {
    param($Nome)
    foreach ($v in @("viewDash","viewConfirm","viewProgress","viewPerfis","viewCustom")) {
        if ($c[$v]) { $c[$v].Visibility = "Collapsed" }
    }
    if ($c[$Nome]) { $c[$Nome].Visibility = "Visible" }
    foreach ($b in @("btnDash","btnQuick","btnPadrao","btnDeep","btnPerfis","btnCustom")) {
        if ($c[$b]) { $c[$b].Tag = "" }
    }
    switch ($Nome) {
        "viewDash"   { if ($c.btnDash)   { $c.btnDash.Tag   = "active" } }
        "viewPerfis" { if ($c.btnPerfis) { $c.btnPerfis.Tag = "active" } }
        "viewCustom" { if ($c.btnCustom) { $c.btnCustom.Tag = "active" } }
    }
}

# ============================================================================
# SERVICOS SILENCIOSOS (BLINDADO CONTRA PATH HIJACKING)
# ============================================================================
function Stop-SvcSilent {
    param([string]$Name, [int]$TimeoutSec = 15)
    try {
        $svc = Get-Service -Name $Name -EA SilentlyContinue
        if ($svc -and $svc.Status -ne "Stopped") {
            $scPath = "$env:SystemRoot\System32\sc.exe"
            & $scPath stop $Name 2>&1 | Out-Null
            $waited = 0
            while ($waited -lt $TimeoutSec) {
                Start-Sleep -Milliseconds 300
                $waited += 0.3
                $svc.Refresh()
                if ($svc.Status -eq "Stopped") { break }
            }
        }
    } catch { }
}

function Start-SvcSilent {
    param([string]$Name)
    try {
        $svc = Get-Service -Name $Name -EA SilentlyContinue
        if ($svc -and $svc.Status -ne "Running") {
            $scPath = "$env:SystemRoot\System32\sc.exe"
            Start-Process -FilePath $scPath -ArgumentList "start", $Name -WindowStyle Hidden -EA SilentlyContinue
        }
    } catch { }
}

# ============================================================================
# LIMPEZA DE PASTAS (BLINDADO CONTRA JUNCTION POINTS)
# ============================================================================
function Limpar-Pasta {
    param($Path, $Nome, $Dias = 0)
    if (-not (Test-Path $Path)) { Log "$Nome - nao encontrado" skip; return }
    $antes = Get-Tam $Path
    if ($antes -eq 0) { Log "$Nome - ja vazio" ok; return }
    Log "Limpando: $Nome" info
    
    $itens = if ($Dias -gt 0) {
        $d = (Get-Date).AddDays(-$Dias)
        Get-ChildItem $Path -Recurse -Force -Attributes !ReparsePoint -EA SilentlyContinue | Where-Object { $_.LastWriteTime -lt $d }
    } else {
        Get-ChildItem $Path -Recurse -Force -Attributes !ReparsePoint -EA SilentlyContinue
    }
    
    foreach ($i in $itens) {
        try {
            $t = if ($i.PSIsContainer) { Get-Tam $i.FullName } else { $i.Length }
            Remove-Item $i.FullName -Recurse -Force -EA SilentlyContinue
            $Global:Espaco += $t
            $Global:Itens++
        } catch { }
    }
    $depois = Get-Tam $Path
    $lib = $antes - $depois
    if ($lib -gt 0) { Log "$Nome - liberado: $(Fmt $lib)" ok } else { Log "$Nome - em uso" skip }
    Upd-Stats
}

function M-TempSys {
    Log "Modulo: Temp Sistema" info
    Limpar-Pasta "$env:SystemRoot\Temp" "Windows Temp"
    Limpar-Pasta "$env:SystemRoot\Prefetch" "Prefetch" 30
}

function M-TempUser {
    Log "Modulo: Temp Usuarios" info
    $ps = Get-ChildItem "C:\Users" -Directory -EA SilentlyContinue | Where-Object { $_.Name -notin @("Public","Default","Default User","All Users") }
    foreach ($p in $ps) {
        Limpar-Pasta (Join-Path $p.FullName "AppData\Local\Temp") "Temp $($p.Name)"
        Limpar-Pasta (Join-Path $p.FullName "AppData\Local\CrashDumps") "CrashDumps $($p.Name)"
    }
}

function M-CachesNav {
    Log "Modulo: Caches Nav" info
    $ps = Get-ChildItem "C:\Users" -Directory -EA SilentlyContinue | Where-Object { $_.Name -notin @("Public","Default","Default User","All Users") }
    foreach ($p in $ps) {
        Limpar-Pasta (Join-Path $p.FullName "AppData\Local\Google\Chrome\User Data\Default\Cache") "Chrome $($p.Name)"
        Limpar-Pasta (Join-Path $p.FullName "AppData\Local\Microsoft\Edge\User Data\Default\Cache") "Edge $($p.Name)"
    }
}

function M-Logs {
    Log "Modulo: Logs" info
    Limpar-Pasta "$env:ProgramData\Microsoft\Windows\WER\ReportArchive" "WER Archive"
    Limpar-Pasta "$env:ProgramData\Microsoft\Windows\WER\ReportQueue" "WER Queue"
}

function M-Lixo {
    Log "Modulo: Lixeira" info
    try {
        $t = Get-Tam "C:\`$Recycle.Bin"
        Clear-RecycleBin -Force -EA SilentlyContinue
        Log "Lixeira esvaziada" ok
        $Global:Espaco += $t
        Upd-Stats
    } catch { Log "Lixeira falhou" skip }
}

function M-WU {
    Log "Modulo: Windows Update" info
    Log "Parando servicos wuauserv e bits..." info
    Stop-SvcSilent -Name "wuauserv"
    Stop-SvcSilent -Name "bits"
    Start-Sleep -Seconds 1
    Limpar-Pasta "$env:SystemRoot\SoftwareDistribution\Download" "Downloads WU"
    Log "Reiniciando servicos em segundo plano..." info
    Start-SvcSilent -Name "wuauserv"
    Start-SvcSilent -Name "bits"
    Log "Windows Update processado" ok
}

function M-DISM {
    Log "Modulo: DISM (pode demorar 5-10 minutos)" info

    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $psJob = [powershell]::Create()
    $psJob.Runspace = $rs
    $null = $psJob.AddScript({
        try {
            $out = Dism.exe /Online /Cleanup-Image /StartComponentCleanup /Quiet 2>&1 | Out-String
            return @{ OK = $true; Output = $out }
        } catch {
            return @{ OK = $false; Output = $_.Exception.Message }
        }
    })
    $handle = $psJob.BeginInvoke()

    $startTime = Get-Date
    $baseProg  = 88
    $maxProg   = 99
    $dots      = 0

    while (-not $handle.IsCompleted) {
        $seconds = [int]((Get-Date) - $startTime).TotalSeconds
        $progresso = [math]::Min($maxProg, $baseProg + [int]($seconds / 15))
        $dots = ($dots + 1) % 4
        $sufixo = "." * $dots
        $min = [int]($seconds / 60)
        $seg = $seconds % 60
        $tempoFormatado = if ($min -gt 0) { "${min}m ${seg}s" } else { "${seg}s" }
        Set-Prog $progresso "DISM em execucao$sufixo (aguarde, operacao pesada - $tempoFormatado)"

        if ($seconds -gt 0 -and $seconds % 30 -eq 0 -and $dots -eq 0) {
            Log "DISM ainda em execucao... ($tempoFormatado)" info
        }

        DoEvents
        Start-Sleep -Milliseconds 500
    }

    $resultado = $psJob.EndInvoke($handle)
    $psJob.Dispose()
    $rs.Close()
    $rs.Dispose()

    if ($resultado -and $resultado[0].OK) {
        $tempoTotal = [int]((Get-Date) - $startTime).TotalSeconds
        Log "DISM concluido com sucesso (${tempoTotal}s)" ok
    } else {
        $errMsg = if ($resultado) { $resultado[0].Output } else { "sem retorno" }
        Log "DISM falhou: $errMsg" err
    }

    Set-Prog 99 "DISM concluido"
}

function Exec-Limpeza {
    param($Tipo)
    if ($Global:EmUso) { return }
    $Global:EmUso = $true
    $c.txtLog.Text = ""
    Show-View "viewProgress"
    $tit = @{ "1"="Limpeza Rapida"; "2"="Limpeza Padrao"; "3"="Limpeza Profunda"; "custom"="Limpeza Personalizada" }
    $c.lblOpTitle.Text = "$($tit[$Tipo]) em execucao"
    Set-Prog 0 "Preparando..."
    Log "Criando ponto de restauracao..." info
    try {
        Checkpoint-Computer -Description "Antes da Limpeza do Sistema" -RestorePointType "MODIFY_SETTINGS" -EA SilentlyContinue
        Log "Ponto de restauracao criado" ok
    } catch { Log "Ponto de restauracao indisponivel" skip }

    $etapas = switch ($Tipo) {
        "1" { @(@{N="Temp Sistema";F={M-TempSys}}, @{N="Temp Usuarios";F={M-TempUser}}) }
        "2" { @(
            @{N="Temp Sistema";F={M-TempSys}},
            @{N="Temp Usuarios";F={M-TempUser}},
            @{N="Caches Nav";F={M-CachesNav}},
            @{N="Logs";F={M-Logs}},
            @{N="Lixeira";F={M-Lixo}}
        )}
        "3" { @(
            @{N="Temp Sistema";F={M-TempSys}},
            @{N="Temp Usuarios";F={M-TempUser}},
            @{N="Caches Nav";F={M-CachesNav}},
            @{N="Logs";F={M-Logs}},
            @{N="Lixeira";F={M-Lixo}},
            @{N="WU";F={M-WU}},
            @{N="DISM";F={M-DISM}}
        )}
        "custom" { $Global:ModsCustom }
    }

    $i = 0
    $total = $etapas.Count
    foreach ($et in $etapas) {
        $i++
        $pctEtapa = if ($et.N -eq "DISM") { 88 } else { [int](($i / $total) * 85) }
        Set-Prog $pctEtapa "Etapa $i de $total : $($et.N)"
        try { & $et.F } catch { Log "Erro em $($et.N): $_" err }
        Upd-Stats
    }

    Set-Prog 100 "Concluido!"
    Log "Espaco liberado: $(Fmt $Global:Espaco)" ok
    Log "Arquivos removidos: $($Global:Itens)" ok
    $Global:Ultima = (Get-Date).ToString("dd/MM/yyyy HH:mm")
    Upd-Stats
    $Global:EmUso = $false
}

function Show-Confirm-Limpeza {
    param($Tipo)
    $Global:PendingTipo = $Tipo

    $titulos = @{
        "1" = "Limpeza Rapida"
        "2" = "Limpeza Padrao"
        "3" = "Limpeza Profunda"
    }
    $descricoes = @{
        "1" = "Remove apenas arquivos temporarios do sistema e dos usuarios. Operacao leve e rapida."
        "2" = "Limpeza media: temporarios + caches de navegadores + logs antigos + lixeira."
        "3" = "Limpeza completa: inclui cache do Windows Update e componentes obsoletos via DISM. Pode demorar ate 15 minutos."
    }
    $modulos = @{
        "1" = @("Temporarios do Sistema", "Temporarios dos Usuarios")
        "2" = @("Temporarios do Sistema", "Temporarios dos Usuarios", "Caches de Navegadores", "Logs Antigos", "Lixeira")
        "3" = @("Temporarios do Sistema", "Temporarios dos Usuarios", "Caches de Navegadores", "Logs Antigos", "Lixeira", "Cache do Windows Update (BITS)", "Componentes Obsoletos (DISM)")
    }

    if ($c.lblConfirmTitle) { $c.lblConfirmTitle.Text = $titulos[$Tipo] }
    if ($c.lblConfirmDesc)  { $c.lblConfirmDesc.Text  = $descricoes[$Tipo] }

    if ($c.stackConfirm) {
        $c.stackConfirm.Children.Clear()
        foreach ($m in $modulos[$Tipo]) {
            $row = New-Object System.Windows.Controls.Border
            $row.Background   = "#0d1233"
            $row.CornerRadius = "6"
            $row.Padding      = "14,10"
            $row.Margin       = "0,3"

            $sp = New-Object System.Windows.Controls.StackPanel
            $sp.Orientation = "Horizontal"

            $bullet = New-Object System.Windows.Controls.TextBlock
            $bullet.Text = "OK"
            $bullet.Foreground = "#00ff88"
            $bullet.FontSize = 13
            $bullet.FontWeight = "Bold"
            $bullet.Margin = "0,0,12,0"
            $bullet.VerticalAlignment = "Center"

            $label = New-Object System.Windows.Controls.TextBlock
            $label.Text = $m
            $label.Foreground = "#ffffff"
            $label.FontSize = 13
            $label.VerticalAlignment = "Center"

            $sp.Children.Add($bullet) | Out-Null
            $sp.Children.Add($label)  | Out-Null
            $row.Child = $sp
            $c.stackConfirm.Children.Add($row) | Out-Null
        }
    }

    Show-View "viewConfirm"
}

function Load-Perfis {
    if ($c.btnRemoverPerfis) { $c.btnRemoverPerfis.IsEnabled = $false }
    if ($c.btnSelAll)        { $c.btnSelAll.IsEnabled = $false }
    if ($c.btnSelNone)       { $c.btnSelNone.IsEnabled = $false }
    if ($c.btnRefreshPerfis) { $c.btnRefreshPerfis.IsEnabled = $false }

    $c.stackPerfis.Children.Clear()

    $loadingPanel = New-Object System.Windows.Controls.StackPanel
    $loadingPanel.HorizontalAlignment = "Center"
    $loadingPanel.Margin = "0,40,0,40"

    $loadingText = New-Object System.Windows.Controls.TextBlock
    $loadingText.Text = "Carregando perfis..."
    $loadingText.Foreground = "#00e5ff"
    $loadingText.FontSize = 18
    $loadingText.FontWeight = "Bold"
    $loadingText.HorizontalAlignment = "Center"

    $loadingSub = New-Object System.Windows.Controls.TextBlock
    $loadingSub.Text = "Lendo C:\Users e calculando tamanhos..."
    $loadingSub.Foreground = "#6b7280"
    $loadingSub.FontSize = 12
    $loadingSub.HorizontalAlignment = "Center"
    $loadingSub.Margin = "0,8,0,0"

    $loadingPanel.Children.Add($loadingText) | Out-Null
    $loadingPanel.Children.Add($loadingSub)   | Out-Null

    $loadingBorder = New-Object System.Windows.Controls.Border
    $loadingBorder.Background = "#0d1233"
    $loadingBorder.CornerRadius = "8"
    $loadingBorder.Padding = "30,40"
    $loadingBorder.HorizontalAlignment = "Center"
    $loadingBorder.Child = $loadingPanel

    $c.stackPerfis.Children.Add($loadingBorder) | Out-Null
    DoEvents

    $resultado = @()
    $usouFallback = $false

    $prot = @(
        "Public", "Default", "Default User", "All Users", "DefaultAppPool",
        "systemprofile", "LocalService", "NetworkService", 
        "IUSR", "IWAM", "SQLService", "MSSQL", "svc_", "ASP.NET"
    )

    try {
        $rs = [runspacefactory]::CreateRunspace()
        $rs.Open()
        $psJob = [powershell]::Create()
        $psJob.Runspace = $rs
        $null = $psJob.AddScript({
            param($protList)
            $lista = @()
            $pastas = Get-ChildItem "C:\Users" -Directory -Force -ErrorAction SilentlyContinue |
                      Where-Object { $_.Name -notin $protList }
            $usr = $env:USERNAME

            foreach ($p in $pastas) {
                $nome = $p.Name
                $logado = ($nome -ieq $usr)
                $nt = Join-Path $p.FullName "NTUSER.DAT"
                if (Test-Path $nt) { $uso = (Get-Item $nt -Force).LastWriteTime }
                else               { $uso = $p.LastWriteTime }

                $tam = 0
                try {
                    $t = (Get-ChildItem $p.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                          Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($null -ne $t) { $tam = $t }
                } catch { }

                $st = "Removivel"; $bloq = $false
                if ($logado) { $st = "EM USO"; $bloq = $true }

                $sid = $null
                try {
                    $cim = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue |
                           Where-Object { $_.LocalPath -ieq $p.FullName } | Select-Object -First 1
                    if ($cim) {
                        $sid = $cim.SID
                        $null = reg query "HKU\$sid" 2>$null
                        if ($LASTEXITCODE -eq 0) { $st = "SESSAO ATIVA"; $bloq = $true }
                    }
                } catch { }

                $lista += [PSCustomObject]@{
                    Nome=$nome; Caminho=$p.FullName; Uso=$uso; Tamanho=$tam
                    Status=$st; SID=$sid; Bloqueado=$bloq
                }
            }
            $lista
        }).AddArgument($prot)
        $handle = $psJob.BeginInvoke()

        $dots = 0
        $startTime = Get-Date
        while (-not $handle.IsCompleted) {
            $dots = ($dots + 1) % 4
            $loadingText.Text = "Carregando perfis" + ("." * $dots)
            $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
            $loadingSub.Text  = "Lendo C:\Users e calculando tamanhos... ($elapsed s)"
            DoEvents
            Start-Sleep -Milliseconds 200
        }
        $resultado = $psJob.EndInvoke($handle)
        $psJob.Dispose(); $rs.Close(); $rs.Dispose()
    } catch { $usouFallback = $true }

    if ($usouFallback -or @($resultado).Count -eq 0) {
        $resultado = @()
        $pastas = Get-ChildItem "C:\Users" -Directory -Force -EA SilentlyContinue | Where-Object { $_.Name -notin $prot }
        $usr = $env:USERNAME
        foreach ($p in $pastas) {
            $nome = $p.Name
            $logado = ($nome -ieq $usr)
            $nt = Join-Path $p.FullName "NTUSER.DAT"
            if (Test-Path $nt) { $uso = (Get-Item $nt -Force).LastWriteTime } else { $uso = $p.LastWriteTime }
            $tam = 0
            try {
                $t = (Get-ChildItem $p.FullName -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum -EA SilentlyContinue).Sum
                if ($null -ne $t) { $tam = $t }
            } catch { }
            $st = "Removivel"; $bloq = $false
            if ($logado) { $st = "EM USO"; $bloq = $true }
            $sid = $null
            try {
                $cim = Get-CimInstance Win32_UserProfile -EA SilentlyContinue | Where-Object { $_.LocalPath -ieq $p.FullName } | Select-Object -First 1
                if ($cim) {
                    $sid = $cim.SID
                    $null = reg query "HKU\$sid" 2>$null
                    if ($LASTEXITCODE -eq 0) { $st = "SESSAO ATIVA"; $bloq = $true }
                }
            } catch { }
            $resultado += [PSCustomObject]@{
                Nome=$nome; Caminho=$p.FullName; Uso=$uso; Tamanho=$tam
                Status=$st; SID=$sid; Bloqueado=$bloq
            }
        }
    }

    $c.stackPerfis.Children.Clear()

    if (@($resultado).Count -eq 0) {
        $t = New-Object System.Windows.Controls.TextBlock
        $t.Text = "Nenhum perfil encontrado."
        $t.Foreground = "#6b7280"
        $t.FontSize = 13
        $t.Margin = "20"
        $t.HorizontalAlignment = "Center"
        $c.stackPerfis.Children.Add($t) | Out-Null
    } else {
        foreach ($item in $resultado) {
            $nome = $item.Nome; $uso = $item.Uso; $tam = $item.Tamanho
            $st = $item.Status; $sid = $item.SID; $bloq = $item.Bloqueado
            $cor = if ($bloq) { "#00ff88" } else { "#ffb800" }

            $row = New-Object System.Windows.Controls.Border
            $row.Background = "#0d1233"; $row.CornerRadius = "6"; $row.Padding = "12,10"; $row.Margin = "0,3"
            $g = New-Object System.Windows.Controls.Grid
            foreach ($w in @("40","*","120","130","110")) {
                $col = New-Object System.Windows.Controls.ColumnDefinition
                if ($w -eq "*") { $col.Width = [System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star) }
                else { $col.Width = [System.Windows.GridLength]::new([double]$w,[System.Windows.GridUnitType]::Pixel) }
                $g.ColumnDefinitions.Add($col)
            }
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.VerticalAlignment = "Center"; $cb.IsEnabled = -not $bloq
            $cb.Tag = @{ Nome=$nome; Caminho=$item.Caminho; SID=$sid; Tamanho=$tam }
            [System.Windows.Controls.Grid]::SetColumn($cb, 0); $g.Children.Add($cb) | Out-Null

            $t1 = New-Object System.Windows.Controls.TextBlock
            $t1.Text = $nome; $t1.Foreground = "#ffffff"; $t1.FontSize = 13; $t1.FontWeight = "SemiBold"; $t1.VerticalAlignment = "Center"
            [System.Windows.Controls.Grid]::SetColumn($t1, 1); $g.Children.Add($t1) | Out-Null

            $t2 = New-Object System.Windows.Controls.TextBlock
            $t2.Text = Fmt $tam; $t2.Foreground = "#00e5ff"; $t2.FontSize = 13; $t2.VerticalAlignment = "Center"
            [System.Windows.Controls.Grid]::SetColumn($t2, 2); $g.Children.Add($t2) | Out-Null

            $t3 = New-Object System.Windows.Controls.TextBlock
            $t3.Text = $uso.ToString("dd/MM/yyyy"); $t3.Foreground = "#6b7280"; $t3.FontSize = 13; $t3.VerticalAlignment = "Center"
            [System.Windows.Controls.Grid]::SetColumn($t3, 3); $g.Children.Add($t3) | Out-Null

            $t4 = New-Object System.Windows.Controls.TextBlock
            $t4.Text = $st; $t4.Foreground = $cor; $t4.FontSize = 12; $t4.FontWeight = "Bold"; $t4.VerticalAlignment = "Center"
            [System.Windows.Controls.Grid]::SetColumn($t4, 4); $g.Children.Add($t4) | Out-Null

            $row.Child = $g
            $c.stackPerfis.Children.Add($row) | Out-Null
        }
    }

    if ($c.btnRemoverPerfis) { $c.btnRemoverPerfis.IsEnabled = $true }
    if ($c.btnSelAll)        { $c.btnSelAll.IsEnabled = $true }
    if ($c.btnSelNone)       { $c.btnSelNone.IsEnabled = $true }
    if ($c.btnRefreshPerfis) { $c.btnRefreshPerfis.IsEnabled = $true }
}

function Remove-Perfis {
    $sel = @()
    foreach ($row in $c.stackPerfis.Children) {
        if ($row -isnot [System.Windows.Controls.Border]) { continue }
        foreach ($ch in $row.Child.Children) {
            if ($ch -is [System.Windows.Controls.CheckBox] -and $ch.IsChecked -eq $true) { $sel += $ch.Tag }
        }
    }
    if ($sel.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Nenhum perfil selecionado.", "Aviso", "OK", "Information") | Out-Null
        return
    }
    $lista = ($sel | ForEach-Object { "  - $($_.Nome)  ($(Fmt $_.Tamanho))" }) -join "`n"
    $msg = "REMOVER PERMANENTEMENTE:`n`n$lista`n`nApaga pasta E registro.`n`nConfirmar?"
    $r = [System.Windows.MessageBox]::Show($msg, "Confirmar", "YesNo", "Warning")
    if ($r -ne "Yes") { return }

    Show-View "viewProgress"
    $c.lblOpTitle.Text = "Removendo perfis..."
    $c.txtLog.Text = ""
    $Global:EmUso = $true
    $i = 0
    foreach ($s in $sel) {
        $i++
        Set-Prog ([int](($i / $sel.Count) * 100)) "Removendo: $($s.Nome)"
        Log "Removendo: $($s.Nome)" info
        $ok = $false
        if ($s.SID) {
            try {
                $cim = Get-CimInstance Win32_UserProfile -Filter "SID='$($s.SID)'" -EA Stop
                Remove-CimInstance -InputObject $cim -EA Stop
                $ok = $true
            } catch { Log "Falha CIM: $($s.Nome)" skip }
        }
        if (-not $ok) {
            try { Remove-Item $s.Caminho -Recurse -Force -EA Stop; $ok = $true }
            catch { Log "Erro: $($s.Nome) - $_" err }
        }
        if ($s.SID) {
            $reg = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$($s.SID)"
            if (Test-Path $reg) { Remove-Item $reg -Recurse -Force -EA SilentlyContinue }
        }
        if ($ok) { $Global:Espaco += $s.Tamanho; $Global:Itens++; Log "OK: $($s.Nome)" ok }
        Upd-Stats
    }
    Set-Prog 100 "Concluido!"
    Log "Remocao finalizada" ok
    $Global:EmUso = $false
    Load-Perfis
}

function Load-Custom {
    $c.stackCustom.Children.Clear()
    $mods = @(
        @{N="Temporarios do Sistema";    F={M-TempSys};   D="Arquivos temporarios do Windows"},
        @{N="Temporarios dos Usuarios";  F={M-TempUser};  D="Temp e CrashDumps"},
        @{N="Caches de Navegadores";     F={M-CachesNav}; D="Chrome e Edge"},
        @{N="Logs Antigos";              F={M-Logs};      D="WER e relatorios"},
        @{N="Lixeira";                   F={M-Lixo};      D="Esvaziar lixeira"},
        @{N="Cache Windows Update";      F={M-WU};        D="Downloads do WU"},
        @{N="Limpeza DISM";              F={M-DISM};      D="Componentes obsoletos (pode demorar)"}
    )
    foreach ($m in $mods) {
        $row = New-Object System.Windows.Controls.Border
        $row.Background = "#0d1233"; $row.CornerRadius = "6"; $row.Padding = "15,12"; $row.Margin = "0,4"
        $sp = New-Object System.Windows.Controls.StackPanel
        $sp.Orientation = "Horizontal"
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.VerticalAlignment = "Center"; $cb.Margin = "0,0,15,0"; $cb.Tag = $m
        $sp.Children.Add($cb) | Out-Null
        $ts = New-Object System.Windows.Controls.StackPanel
        $l1 = New-Object System.Windows.Controls.TextBlock
        $l1.Text = $m.N; $l1.Foreground = "#ffffff"; $l1.FontSize = 14; $l1.FontWeight = "SemiBold"
        $ts.Children.Add($l1) | Out-Null
        $l2 = New-Object System.Windows.Controls.TextBlock
        $l2.Text = $m.D; $l2.Foreground = "#6b7280"; $l2.FontSize = 11; $l2.Margin = "0,3,0,0"
        $ts.Children.Add($l2) | Out-Null
        $sp.Children.Add($ts) | Out-Null
        $row.Child = $sp
        $c.stackCustom.Children.Add($row) | Out-Null
    }
}

# ============================================================================
# EVENTOS
# ============================================================================
if ($c.titleBar) { $c.titleBar.Add_MouseLeftButtonDown({ try { $window.DragMove() } catch { } }) }
if ($c.btnClose) { $c.btnClose.Add_Click({ $window.Close() }) }
if ($c.btnMin)   { $c.btnMin.Add_Click({ $window.WindowState = "Minimized" }) }
if ($c.btnMax)   { $c.btnMax.Add_Click({ if ($window.WindowState -eq "Maximized") { $window.WindowState = "Normal" } else { $window.WindowState = "Maximized" } }) }

if ($c.btnDash)   { $c.btnDash.Add_Click({ Show-View "viewDash" }) }
if ($c.btnQuick)  { $c.btnQuick.Add_Click({ Show-Confirm-Limpeza "1" }) }
if ($c.btnPadrao) { $c.btnPadrao.Add_Click({ Show-Confirm-Limpeza "2" }) }
if ($c.btnDeep)   { $c.btnDeep.Add_Click({ Show-Confirm-Limpeza "3" }) }
if ($c.btnPerfis) { $c.btnPerfis.Add_Click({ Show-View "viewPerfis"; Load-Perfis }) }
if ($c.btnCustom) { $c.btnCustom.Add_Click({ Show-View "viewCustom"; Load-Custom }) }

if ($c.cardQuick)  { $c.cardQuick.Add_Click({ Show-Confirm-Limpeza "1" }) }
if ($c.cardPadrao) { $c.cardPadrao.Add_Click({ Show-Confirm-Limpeza "2" }) }
if ($c.cardDeep)   { $c.cardDeep.Add_Click({ Show-Confirm-Limpeza "3" }) }

if ($c.btnIniciarLimpeza) {
    $c.btnIniciarLimpeza.Add_Click({
        if ($Global:PendingTipo) { Exec-Limpeza $Global:PendingTipo }
    })
}
if ($c.btnCancelarLimpeza) {
    $c.btnCancelarLimpeza.Add_Click({ Show-View "viewDash" })
}

if ($c.btnVoltarDash) { $c.btnVoltarDash.Add_Click({ Show-View "viewDash" }) }

if ($c.btnSelAll)  { $c.btnSelAll.Add_Click({
    foreach ($r in $c.stackPerfis.Children) { if ($r -isnot [System.Windows.Controls.Border]) { continue }; foreach ($ch in $r.Child.Children) { if ($ch -is [System.Windows.Controls.CheckBox] -and $ch.IsEnabled) { $ch.IsChecked = $true } } }
}) }
if ($c.btnSelNone) { $c.btnSelNone.Add_Click({
    foreach ($r in $c.stackPerfis.Children) { if ($r -isnot [System.Windows.Controls.Border]) { continue }; foreach ($ch in $r.Child.Children) { if ($ch -is [System.Windows.Controls.CheckBox]) { $ch.IsChecked = $false } } }
}) }
if ($c.btnRefreshPerfis) { $c.btnRefreshPerfis.Add_Click({ Load-Perfis }) }
if ($c.btnRemoverPerfis) { $c.btnRemoverPerfis.Add_Click({ Remove-Perfis }) }

if ($c.btnExecCustom) {
    $c.btnExecCustom.Add_Click({
        $Global:ModsCustom = @()
        foreach ($r in $c.stackCustom.Children) {
            if ($r -isnot [System.Windows.Controls.Border]) { continue }
            foreach ($ch in $r.Child.Children) {
                if ($ch -is [System.Windows.Controls.CheckBox] -and $ch.IsChecked -eq $true) {
                    $Global:ModsCustom += @{ N = $ch.Tag.N; F = $ch.Tag.F }
                }
            }
        }
        if ($Global:ModsCustom.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Selecione ao menos um modulo.", "Aviso", "OK", "Information") | Out-Null
            return
        }
        Exec-Limpeza "custom"
    })
}

try {
    Upd-Stats
    $window.Opacity = 0
    $window.Add_Loaded({
        try {
            $a = New-Object System.Windows.Media.Animation.DoubleAnimation
            $a.From = 0; $a.To = 1
            $a.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(350))
            $window.BeginAnimation([System.Windows.Window]::OpacityProperty, $a)
        } catch { }
    })
    $window.ShowDialog() | Out-Null
} catch {
    [System.IO.File]::WriteAllText($Global:ErrorLog, "ERRO: $(Get-Date)`n$($_.Exception.Message)`n$($_.ScriptStackTrace)", [System.Text.Encoding]::UTF8)
    try { [System.Windows.MessageBox]::Show("Erro: $($_.Exception.Message)`n`nDetalhes em: $Global:ErrorLog", "Erro", "OK", "Error") | Out-Null } catch { }
}
